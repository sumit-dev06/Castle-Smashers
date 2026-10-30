package com.castlesmashers.firebase

import android.os.Bundle
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Firebase Analytics + Crashlytics for Castle Smashers (singleton "CastleFirebase").
 * Firebase initialises from the google_app_id/api_key/project_id strings that the
 * google-services Gradle plugin generates from google-services.json. Without that file the
 * plugin reports available() == false and every call is a no-op, so builds keep working.
 */
class CastleFirebase(godot: Godot) : GodotPlugin(godot) {
    private var analytics: FirebaseAnalytics? = null
    private var crashlytics: FirebaseCrashlytics? = null

    override fun getPluginName() = "CastleFirebase"

    init {
        try {
            val ctx = godot.getActivity()?.applicationContext
            if (ctx != null && (FirebaseApp.getApps(ctx).isNotEmpty() || FirebaseApp.initializeApp(ctx) != null)) {
                analytics = FirebaseAnalytics.getInstance(ctx)
                crashlytics = FirebaseCrashlytics.getInstance()
            }
        } catch (e: Exception) {
            Log.w("CastleFirebase", "Firebase not configured: ${e.message}")
        }
    }

    @UsedByGodot
    fun available(): Boolean = analytics != null

    @UsedByGodot
    fun logEvent(name: String, params: Dictionary) {
        val a = analytics ?: return
        val b = Bundle()
        for (key in params.keys) {
            when (val v = params[key]) {
                is Int -> b.putLong(key, v.toLong())
                is Long -> b.putLong(key, v)
                is Double -> b.putDouble(key, v)
                is Float -> b.putDouble(key, v.toDouble())
                is Boolean -> b.putLong(key, if (v) 1L else 0L)
                null -> {}
                else -> b.putString(key, v.toString().take(100))
            }
        }
        a.logEvent(name, b)
    }

    @UsedByGodot
    fun setUserProperty(name: String, value: String) {
        analytics?.setUserProperty(name, value.take(36))
    }

    @UsedByGodot
    fun log(message: String) {
        crashlytics?.log(message.take(400))
    }

    @UsedByGodot
    fun setCustomKey(key: String, value: String) {
        crashlytics?.setCustomKey(key, value.take(100))
    }

    @UsedByGodot
    fun recordError(message: String) {
        crashlytics?.recordException(RuntimeException(message.take(400)))
    }

    /** Player opt-out (settings): stops both analytics and crash collection. */
    @UsedByGodot
    fun setCollectionEnabled(on: Boolean) {
        analytics?.setAnalyticsCollectionEnabled(on)
        crashlytics?.setCrashlyticsCollectionEnabled(on)
    }
}
