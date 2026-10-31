package com.castlesmashers.notify

import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.review.ReviewManagerFactory
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Google Play In-App Review and In-App Updates (singleton "CastlePlay"). Both only work in a copy
 * installed from Google Play; elsewhere every call quietly reports "nothing to do".
 *
 * Signals:
 *  review_finished(shown_flow: bool)        - Play decides itself whether the card really appears
 *  update_checked(available: bool, version_code: int, priority: int, staleness_days: int)
 *  update_downloaded()                      - a flexible update is ready; call completeUpdate()
 *  update_failed(reason: String)
 */
class CastlePlay(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "CastlePlay"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("review_finished", java.lang.Boolean::class.java),
        SignalInfo("update_checked", java.lang.Boolean::class.java, Integer::class.java, Integer::class.java, Integer::class.java),
        SignalInfo("update_downloaded"),
        SignalInfo("update_failed", String::class.java),
    )

    private var updates: AppUpdateManager? = null
    private var lastInfo: AppUpdateInfo? = null
    private val listener = InstallStateUpdatedListener { state ->
        when (state.installStatus()) {
            InstallStatus.DOWNLOADED -> emitSignal("update_downloaded")
            InstallStatus.FAILED -> emitSignal("update_failed", "install_failed_${state.installErrorCode()}")
            else -> {}
        }
    }

    private fun manager(): AppUpdateManager? {
        if (updates == null) {
            val a = godot.getActivity() ?: return null
            updates = AppUpdateManagerFactory.create(a.applicationContext).also { it.registerListener(listener) }
        }
        return updates
    }

    /** Asks Play for the review card. Play applies its own quota, so it may show nothing. */
    @UsedByGodot
    fun requestReview() {
        val a = godot.getActivity() ?: return emitSignal("review_finished", false)
        val rm = ReviewManagerFactory.create(a.applicationContext)
        rm.requestReviewFlow().addOnCompleteListener { req ->
            if (!req.isSuccessful) {
                emitSignal("review_finished", false)
                return@addOnCompleteListener
            }
            a.runOnUiThread {
                rm.launchReviewFlow(a, req.result).addOnCompleteListener { emitSignal("review_finished", true) }
            }
        }
    }

    /** Is a newer version on Play? Answers with update_checked. */
    @UsedByGodot
    fun checkUpdate() {
        val m = manager() ?: return emitSignal("update_checked", false, 0, 0, 0)
        m.appUpdateInfo.addOnSuccessListener { info ->
            lastInfo = info
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emitSignal("update_downloaded")
                return@addOnSuccessListener
            }
            val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
            emitSignal("update_checked", available, info.availableVersionCode(), info.updatePriority(),
                info.clientVersionStalenessDays() ?: 0)
        }.addOnFailureListener { emitSignal("update_checked", false, 0, 0, 0) }
    }

    /**
     * Starts Play's update screen for the info from the last checkUpdate().
     * immediate = true: full-screen, blocking update (for critical fixes).
     * immediate = false: flexible, downloads in the background while the player keeps playing.
     */
    @UsedByGodot
    fun startUpdate(immediate: Boolean): Boolean {
        val a = godot.getActivity() ?: return false
        val m = manager() ?: return false
        val info = lastInfo ?: return false
        val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
        if (!info.isUpdateTypeAllowed(type)) return false
        return try {
            a.runOnUiThread {
                m.startUpdateFlow(info, a, AppUpdateOptions.newBuilder(type).build())
                    .addOnFailureListener { emitSignal("update_failed", it.message ?: "start_failed") }
            }
            true
        } catch (e: Exception) {
            emitSignal("update_failed", e.message ?: "start_failed")
            false
        }
    }

    /** Installs a downloaded flexible update. In the background it installs quietly; in the
     *  foreground Play shows its install screen and restarts the game. */
    @UsedByGodot
    fun completeUpdate() {
        manager()?.completeUpdate()
    }

    override fun onMainResume() {
        super.onMainResume()
        // An immediate update the player left half-way must be resumed (Play's rule).
        val m = updates ?: return
        val a = godot.getActivity() ?: return
        m.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                m.startUpdateFlow(info, a, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build())
            } else if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emitSignal("update_downloaded")
            }
        }
    }

    override fun onMainDestroy() {
        updates?.unregisterListener(listener)
        super.onMainDestroy()
    }
}
