package com.castlesmashers.notify

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Local notifications for Castle Smashers (singleton "CastleNotify"). Notifications are
 * scheduled with AlarmManager (inexact, battery friendly) and shown by NotifyReceiver even when
 * the game is closed. Tapping one opens the game; lastOpenedKind() tells Godot which one it was.
 */
class CastleNotify(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "CastleNotify"

    private fun ctx(): Context? = godot.getActivity()?.applicationContext

    @UsedByGodot
    fun hasPermission(): Boolean {
        val c = ctx() ?: return false
        return Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    /** Android 13+: shows the system permission dialog (no-op on older versions). */
    @UsedByGodot
    fun requestPermission() {
        val a = godot.getActivity() ?: return
        if (Build.VERSION.SDK_INT >= 33 && !hasPermission()) {
            ActivityCompat.requestPermissions(a, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7301)
        }
    }

    /** Schedules notification `id` in `delaySec` seconds (replacing any with the same id). */
    @UsedByGodot
    fun schedule(id: Int, title: String, body: String, delaySec: Int, kind: String) {
        val c = ctx() ?: return
        NotifyReceiver.ensureChannel(c)
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + delaySec * 1000L, pending(c, id, title, body, kind))
    }

    @UsedByGodot
    fun cancel(id: Int) {
        val c = ctx() ?: return
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(c, id, "", "", ""))
        NotificationManagerCompat.from(c).cancel(id)
    }

    @UsedByGodot
    fun cancelAll(ids: IntArray) {
        for (id in ids) cancel(id)
    }

    /** Kind of the notification that opened the game ("" if none), cleared after reading. */
    @UsedByGodot
    fun lastOpenedKind(): String {
        val a = godot.getActivity() ?: return ""
        val k = a.intent?.getStringExtra(NotifyReceiver.EXTRA_KIND) ?: ""
        a.intent?.removeExtra(NotifyReceiver.EXTRA_KIND)
        return k
    }

    private fun pending(c: Context, id: Int, title: String, body: String, kind: String): PendingIntent {
        val i = Intent(c, NotifyReceiver::class.java)
            .putExtra(NotifyReceiver.EXTRA_ID, id).putExtra(NotifyReceiver.EXTRA_TITLE, title)
            .putExtra(NotifyReceiver.EXTRA_BODY, body).putExtra(NotifyReceiver.EXTRA_KIND, kind)
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class NotifyReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL = "castle_reminders"
        const val EXTRA_ID = "cs_id"
        const val EXTRA_TITLE = "cs_title"
        const val EXTRA_BODY = "cs_body"
        const val EXTRA_KIND = "cs_kind"

        fun ensureChannel(c: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val nm = c.getSystemService(NotificationManager::class.java)
                if (nm.getNotificationChannel(CHANNEL) == null) {
                    nm.createNotificationChannel(NotificationChannel(CHANNEL, "Siege reminders", NotificationManager.IMPORTANCE_DEFAULT)
                        .apply { description = "Daily spin, rewards and new levels" })
                }
            }
        }
    }

    override fun onReceive(c: Context, intent: Intent) {
        ensureChannel(c)
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val launch = c.packageManager.getLaunchIntentForPackage(c.packageName) ?: return
        launch.putExtra(EXTRA_KIND, intent.getStringExtra(EXTRA_KIND) ?: "")
        launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val id = intent.getIntExtra(EXTRA_ID, 1)
        val open = PendingIntent.getActivity(c, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val icon = c.resources.getIdentifier("icon_monochrome", "mipmap", c.packageName).takeIf { it != 0 }
            ?: c.applicationInfo.icon
        val n = NotificationCompat.Builder(c, CHANNEL)
            .setSmallIcon(icon)
            .setContentTitle(intent.getStringExtra(EXTRA_TITLE))
            .setContentText(intent.getStringExtra(EXTRA_BODY))
            .setStyle(NotificationCompat.BigTextStyle().bigText(intent.getStringExtra(EXTRA_BODY)))
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        NotificationManagerCompat.from(c).notify(id, n)
    }
}
