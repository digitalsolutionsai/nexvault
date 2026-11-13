package app.nexvault.nexvault

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import java.io.File

/**
 * Share target ("Chia sẻ → NexVault") for a QR image or a nexvault:// text from another app.
 * Has no UI: it copies the image into the app cache and hands it to the existing
 * NexVault task, so a share from Zalo/Messenger does not start a second app instance
 * inside the sender's task.
 */
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val link = try { linkFrom(intent) } catch (_: Exception) { null }
        if (link != null) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .putExtra(MainActivity.EXTRA_LINK, link)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            )
        }
        finish()
    }

    private fun linkFrom(i: Intent): String? {
        if (i.action != Intent.ACTION_SEND) return null
        i.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.let { t ->
            if (t.startsWith("nexvault://")) return t
        }
        val uri: Uri = (if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else @Suppress("DEPRECATION") i.getParcelableExtra(Intent.EXTRA_STREAM)) ?: return null
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() } // only the latest shared image is kept
        val f = File(dir, "qr-${System.currentTimeMillis()}")
        contentResolver.openInputStream(uri)?.use { input ->
            f.outputStream().use { out ->
                // a QR screenshot is small; refuse anything huge
                val buf = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > 20L * 1024 * 1024) { f.delete(); return null }
                    out.write(buf, 0, n)
                }
            }
        } ?: return null
        return MainActivity.IMAGE_PREFIX + f.path
    }
}
