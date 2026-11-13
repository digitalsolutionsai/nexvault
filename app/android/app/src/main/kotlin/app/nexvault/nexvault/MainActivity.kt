package app.nexvault.nexvault

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import android.app.KeyguardManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Native side of NexVault:
 *  - FLAG_SECURE on every screen (no screenshots, blank in recents)
 *  - vault key sealed by an Android Keystore AES key that needs user authentication for every
 *    use (BiometricPrompt + CryptoObject). Two seals ("kind"):
 *      dev: strong biometric OR the device lock-screen credential (default custody; the lock
 *           screen is throttled by Gatekeeper/Weaver in the TEE). API 30+.
 *      bio: strong biometric only, next to an app PIN (PIN custody); invalidated when
 *           fingerprints change.
 *  - clipboard copy flagged as sensitive, cleared after 30 s
 *  - nexvault:// deep links
 */
class MainActivity : FlutterFragmentActivity() {
    private lateinit var channel: MethodChannel
    companion object {
        const val EXTRA_LINK = "app.nexvault.LINK"
        const val IMAGE_PREFIX = "nexvault-image:"
    }

    private var pendingLink: String? = null
    private var labelUsePin = "Use PIN" // biometric prompt button, in the app language (setLabels)
    private var printView: android.webkit.WebView? = null // kept alive while the print job runs
    /** One Keystore seal of the vault key. */
    private inner class Seal(val dev: Boolean) {
        val alias = if (dev) "nexvault_dev_v1" else "nexvault_bio_v1"
        val prefs = getSharedPreferences(if (dev) "nexvault_dev" else "nexvault_bio", Context.MODE_PRIVATE)
        val authenticators = if (dev) BIOMETRIC_STRONG or DEVICE_CREDENTIAL else BIOMETRIC_STRONG
    }
    private val bioSeal by lazy { Seal(false) }
    private val devSeal by lazy { Seal(true) }
    private fun seal(call: io.flutter.plugin.common.MethodCall) = if (call.argument<String>("kind") == "dev") devSeal else bioSeal

    /** Device lock-screen custody needs API 30 (crypto + device credential) and a secure lock screen. */
    /**
     * Print an HTML page through the system print dialog. The page is rendered in memory by an
     * offline WebView (no JavaScript, no network, no files); the app writes nothing to disk.
     * Replies when the dialog closes, so the pause it causes is not taken as leaving the app.
     */
    private fun printHtml(html: String, result: MethodChannel.Result) {
        val wv = android.webkit.WebView(this)
        wv.settings.javaScriptEnabled = false
        wv.settings.allowFileAccess = false
        wv.settings.allowContentAccess = false
        wv.settings.blockNetworkLoads = true
        var started = false
        wv.webViewClient = object : android.webkit.WebViewClient() {
            override fun onPageFinished(view: android.webkit.WebView, url: String?) {
                if (started) return
                started = true
                val inner = view.createPrintDocumentAdapter("NexVault")
                val adapter = object : android.print.PrintDocumentAdapter() {
                    override fun onStart() = inner.onStart()
                    override fun onLayout(
                        old: android.print.PrintAttributes?, new: android.print.PrintAttributes,
                        cancel: android.os.CancellationSignal?, cb: LayoutResultCallback, extras: Bundle?,
                    ) = inner.onLayout(old, new, cancel, cb, extras)
                    override fun onWrite(
                        pages: Array<out android.print.PageRange>, out: android.os.ParcelFileDescriptor,
                        cancel: android.os.CancellationSignal?, cb: WriteResultCallback,
                    ) = inner.onWrite(pages, out, cancel, cb)
                    override fun onFinish() {
                        inner.onFinish()
                        view.destroy()
                        printView = null
                        result.success(true)
                    }
                }
                val pm = getSystemService(Context.PRINT_SERVICE) as android.print.PrintManager
                pm.print("NexVault", adapter, null)
            }
        }
        printView = wv
        wv.loadDataWithBaseURL(null, html, "text/html", "utf-8", null)
    }

    /** The name the user gave the phone (Settings > About), else the model, e.g. "Galaxy S24". */
    private fun deviceName(): String {
        val set = if (Build.VERSION.SDK_INT >= 25)
            android.provider.Settings.Global.getString(contentResolver, android.provider.Settings.Global.DEVICE_NAME)
        else null
        return set?.trim()?.takeIf { it.isNotEmpty() } ?: Build.MODEL
    }

    private fun devAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < 30) return false
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return km.isDeviceSecure &&
            BiometricManager.from(this).canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL) == BiometricManager.BIOMETRIC_SUCCESS
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Debug builds only: `adb shell run-as app.nexvault touch files/allow_screenshots` lets the
        // test harness capture screens. Release builds always set FLAG_SECURE.
        val debuggable = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val allow = debuggable && java.io.File(filesDir, "allow_screenshots").exists()
        if (!allow) window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        pendingLink = linkOf(intent)
    }

    /** nexvault:// deep link, or a shared QR image handed over by [ShareReceiverActivity]. */
    private fun linkOf(i: Intent?): String? {
        val extra = i?.getStringExtra(EXTRA_LINK)
        if (extra != null) {
            // MainActivity is exported: any app can send this extra. Only accept images that
            // ShareReceiverActivity itself wrote, never an arbitrary path (Dart deletes the file
            // after decoding it, so a path to the vault would be destructive).
            if (extra.startsWith("nexvault://")) return extra
            if (extra.startsWith(IMAGE_PREFIX)) {
                val f = java.io.File(extra.removePrefix(IMAGE_PREFIX)).canonicalFile
                val shared = java.io.File(cacheDir, "shared").canonicalFile
                if (f.parentFile == shared && f.isFile) return IMAGE_PREFIX + f.path
            }
            return null
        }
        return i?.dataString?.takeIf { it.startsWith("nexvault://") }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkOf(intent)?.let { link ->
            if (::channel.isInitialized) channel.invokeMethod("link", link) else pendingLink = link
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexvault/native")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialLink" -> { result.success(pendingLink); pendingLink = null }
                "bioAvailable" -> result.success(
                    BiometricManager.from(this).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                )
                "devAvailable" -> result.success(devAvailable())
                "deviceName" -> result.success(deviceName())
                "setLabels" -> {
                    labelUsePin = call.argument<String>("usePin") ?: labelUsePin
                    result.success(null)
                }
                "printHtml" -> printHtml(call.argument<String>("html")!!, result)
                "bioEnabled" -> result.success(seal(call).prefs.contains("ct"))
                "bioEnroll" -> bioEnroll(seal(call), call.argument<String>("title")!!, result)
                "bioUnlock" -> bioUnlock(seal(call), call.argument<String>("title")!!, call.argument<String>("dir")!!, result)
                "bioCheck" -> bioCheck(seal(call), call.argument<String>("title")!!, result)
                "bioClear" -> { val k = seal(call); k.prefs.edit().clear().apply(); deleteKey(k); result.success(null) }
                "netIfaces" -> result.success(netIfaces())
                "openAppSettings" -> {
                    startActivity(
                        Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.fromParts("package", packageName, null))
                    )
                    result.success(null)
                }
                "copySensitive" -> { copySensitive(call.argument<String>("label")!!, call.argument<String>("text")!!); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Interface names of networks that peers can actually reach us on: Wi-Fi, Ethernet, VPN,
     * and cellular networks that carry internet. Excludes the IMS/VoLTE bearer, which has a
     * global IPv6 on an rmnet interface that apps can never use.
     */
    private fun netIfaces(): List<String> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val out = mutableListOf<String>()
        @Suppress("DEPRECATION")
        for (n in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(n) ?: continue
            val lp = cm.getLinkProperties(n) ?: continue
            val lan = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            val net = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            if (!lan && !net) continue
            lp.interfaceName?.let(out::add)
        }
        return out.distinct()
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun deleteKey(k: Seal) = try { keyStore().deleteEntry(k.alias) } catch (_: Exception) {}

    private fun createKey(k: Seal): SecretKey {
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(k.alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            // the device-credential seal must survive a new fingerprint (the passcode still works)
            .setInvalidatedByBiometricEnrollment(!k.dev)
            .apply {
                if (Build.VERSION.SDK_INT >= 30) {
                    setUserAuthenticationParameters(
                        0,
                        if (k.dev) KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL else KeyProperties.AUTH_BIOMETRIC_STRONG,
                    )
                }
            }
            .build()
        gen.init(spec)
        return gen.generateKey()
    }

    private fun prompt(k: Seal, title: String, cipher: Cipher, onOk: (Cipher) -> Unit, onErr: (String, String) -> Unit) {
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setAllowedAuthenticators(k.authenticators)
            // a negative button is not allowed together with DEVICE_CREDENTIAL
            .apply { if (!k.dev) setNegativeButtonText(labelUsePin) }
            .build()
        val bp = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                r.cryptoObject?.cipher?.let(onOk) ?: onErr("no_cipher", "no cipher from the prompt")
            }
            override fun onAuthenticationError(code: Int, msg: CharSequence) {
                onErr(if (code == BiometricPrompt.ERROR_NEGATIVE_BUTTON || code == BiometricPrompt.ERROR_USER_CANCELED) "cancel" else "error", msg.toString())
            }
        })
        bp.authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }

    private fun bioEnroll(k: Seal, title: String, result: MethodChannel.Result) {
        try {
            deleteKey(k)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, createKey(k)) }
            prompt(k, title, cipher, { c ->
                // the vault key comes straight from the core and is wiped right after sealing
                val m = NativeCore.masterForSeal()
                if (m == null) {
                    result.error("locked", "vault is locked", null)
                    return@prompt
                }
                try {
                    val ct = c.doFinal(m)
                    k.prefs.edit()
                        .putString("iv", Base64.encodeToString(c.iv, Base64.NO_WRAP))
                        .putString("ct", Base64.encodeToString(ct, Base64.NO_WRAP))
                        .apply()
                    result.success(true)
                } finally {
                    m.fill(0)
                }
            }, { code, msg -> result.error(code, msg, null) })
        } catch (e: Exception) {
            result.error("error", e.message, null)
        }
    }

    /** Biometric prompt, then decrypt the sealed vault key and hand it to [use] (wiped after). */
    private fun withUnsealedKey(k: Seal, title: String, result: MethodChannel.Result, use: (ByteArray) -> Unit) {
        val iv = k.prefs.getString("iv", null)
        val ct = k.prefs.getString("ct", null)
        if (iv == null || ct == null) return result.error("not_enrolled", "no sealed key", null)
        try {
            val key = keyStore().getKey(k.alias, null) as SecretKey? ?: throw KeyPermanentlyInvalidatedException()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
            prompt(k, title, cipher, { c ->
                var m: ByteArray? = null
                try {
                    m = c.doFinal(Base64.decode(ct, Base64.NO_WRAP))
                    use(m)
                } catch (e: Exception) {
                    result.error("error", e.message, null)
                } finally {
                    m?.fill(0)
                }
            }, { code, msg -> result.error(code, msg, null) })
        } catch (e: KeyPermanentlyInvalidatedException) {
            k.prefs.edit().clear().apply(); deleteKey(k)
            result.error("invalidated", "key permanently invalidated", null)
        } catch (e: Exception) {
            result.error("error", e.message, null)
        }
    }

    /** Unlock: the key goes Keystore -> here -> core; Dart only gets the open result. */
    private fun bioUnlock(k: Seal, title: String, dir: String, result: MethodChannel.Result) =
        withUnsealedKey(k, title, result) { m -> result.success(NativeCore.openWithKey(dir, m)) }

    /** Re-authentication while unlocked: true if the scan unseals the open vault's key. */
    private fun bioCheck(k: Seal, title: String, result: MethodChannel.Result) =
        withUnsealedKey(k, title, result) { m -> result.success(NativeCore.checkKey(m)) }

    private fun copySensitive(label: String, text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText(label, text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(if (Build.VERSION.SDK_INT >= 33) ClipDescription.EXTRA_IS_SENSITIVE else "android.content.extra.IS_SENSITIVE", true)
        }
        cm.setPrimaryClip(clip)
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val cur = cm.primaryClip
                if (cur != null && cur.itemCount > 0 && cur.getItemAt(0).text?.toString() == text) {
                    if (Build.VERSION.SDK_INT >= 28) cm.clearPrimaryClip() else cm.setPrimaryClip(ClipData.newPlainText("", ""))
                }
            } catch (_: Exception) {}
        }, 30_000)
    }
}

/** JNI entry points into the Rust core (core/src/jni.rs); same library dart:ffi loads. */
object NativeCore {
    init {
        System.loadLibrary("nexvault_core")
    }

    @JvmStatic external fun masterForSeal(): ByteArray?
    @JvmStatic external fun openWithKey(dir: String, key: ByteArray): String
    @JvmStatic external fun checkKey(key: ByteArray): Boolean
}
