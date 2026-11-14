package app.nexvault.nexvault

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * A private Wi-Fi for pairing and sync when the people in the room share no usable Wi-Fi (cafés
 * and guest networks often block devices from reaching each other).
 *
 * Host: Android's local-only hotspot (no internet, random name and password, gone when closed).
 * API 33+ only, so it needs NEARBY_WIFI_DEVICES ("neverForLocation") and never location access.
 * Joiner: an app-requested Wi-Fi network (API 29+, the user confirms in a system dialog). The
 * app's sockets, including the Rust core's, are bound to it until [leave].
 *
 * This only carries packets: the sync itself stays end-to-end encrypted and authenticated.
 */
class Hotspot(private val activity: MainActivity, private val stopped: () -> Unit) {
    companion object {
        const val REQ_NEARBY = 4711
    }

    private val main = Handler(Looper.getMainLooper())
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var pendingStart: MethodChannel.Result? = null
    private var joined: ConnectivityManager.NetworkCallback? = null
    private val cm get() = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    fun supported() = Build.VERSION.SDK_INT >= 33

    fun permitted() = supported() &&
        activity.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED

    fun start(result: MethodChannel.Result) {
        if (!supported()) return result.error("unsupported", "local-only hotspot needs Android 13", null)
        if (reservation != null) return result.success(info())
        if (activity.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) != PackageManager.PERMISSION_GRANTED) {
            pendingStart = result
            activity.requestPermissions(arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES), REQ_NEARBY)
            return
        }
        open(result)
    }

    fun onPermission(granted: Boolean) {
        val r = pendingStart ?: return
        pendingStart = null
        if (granted) open(r) else r.error("denied", "nearby devices permission denied", null)
    }

    private fun open(result: MethodChannel.Result) {
        val wm = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        var replied = false
        try {
            wm.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(r: WifiManager.LocalOnlyHotspotReservation) {
                    reservation = r
                    if (!replied) { replied = true; result.success(info()) }
                }
                override fun onFailed(reason: Int) {
                    if (!replied) { replied = true; result.error("failed", "hotspot failed ($reason)", null) }
                }
                override fun onStopped() {
                    reservation = null
                    stopped()
                }
            }, main)
        } catch (e: SecurityException) {
            result.error("denied", e.message, null)
        } catch (e: IllegalStateException) {
            result.error("failed", e.message, null)
        }
    }

    private fun info(): Map<String, Any?> {
        val c = reservation!!.softApConfiguration
        @Suppress("DEPRECATION")
        return mapOf("ssid" to c.ssid, "pass" to c.passphrase, "sec" to c.securityType)
    }

    fun stop() {
        reservation?.close()
        reservation = null
    }

    /** Interfaces of the running hotspot, so the core puts their addresses in the code. */
    fun ifaces(known: List<String>): List<String> {
        if (reservation == null) return emptyList()
        val skip = listOf("lo", "rmnet", "ccmni", "v4-", "clat", "dummy", "tun", "ip6tnl", "sit")
        return NetworkInterface.getNetworkInterfaces().toList().filter { i ->
            i.isUp && i.name !in known && skip.none { i.name.startsWith(it) } &&
                i.inetAddresses.toList().any { it is Inet4Address && it.isSiteLocalAddress }
        }.map { it.name }
    }

    /** Join the other device's hotspot; replies once connected (or failed / declined). */
    fun join(ssid: String, pass: String, sec: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) return result.error("unsupported", "needs Android 10", null)
        leave()
        val spec = WifiNetworkSpecifier.Builder().setSsid(ssid).apply {
            // 1 = WPA2, 2 = WPA3 transition (WPA2 works), 3 = WPA3 only
            if (sec == 3) setWpa3Passphrase(pass) else setWpa2Passphrase(pass)
        }.build()
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(spec)
            .build()
        var replied = false
        fun reply(f: () -> Unit) = main.post { if (!replied) { replied = true; f() } }
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(n: Network) {
                // An always-on VPN that apps cannot bypass keeps every socket on itself, and
                // the bind is refused: without it nothing reaches the other phone, so say so.
                if (cm.bindProcessToNetwork(n)) {
                    reply { result.success(true) }
                } else {
                    main.post { leave() }
                    reply { result.error("vpn", "a VPN keeps the app off $ssid", null) }
                }
            }
            override fun onUnavailable() {
                joined = null
                reply { result.error("unavailable", "could not join $ssid", null) }
            }
            override fun onLost(n: Network) {
                cm.bindProcessToNetwork(null)
            }
        }
        joined = cb
        cm.requestNetwork(req, cb, 45_000)
    }

    fun leave() {
        val cb = joined ?: return
        joined = null
        cm.bindProcessToNetwork(null)
        try { cm.unregisterNetworkCallback(cb) } catch (_: Exception) {}
    }
}
