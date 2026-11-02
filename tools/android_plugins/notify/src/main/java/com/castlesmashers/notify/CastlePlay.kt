package com.castlesmashers.notify

import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
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
 *  games_signed_in(signed_in: bool, display_name: String, error: String)
 *                                           - Google Play Games: answer to gamesCheck()/gamesSignIn()
 *  cloud_loaded(ok: bool, data: String, error: String)  - answer to cloudLoad() ("" = no cloud save yet)
 *  cloud_saved(ok: bool, error: String)                 - answer to cloudSave()
 *
 * Play Games Services v2 signs the player in by itself when the game starts (if they once chose
 * to). gamesCheck() reads that result; gamesSignIn() is the manual button. The project id is in
 * res/values/games_ids.xml. No player id leaves this file; only the display name is passed up.
 */
class CastlePlay(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "CastlePlay"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("review_finished", java.lang.Boolean::class.java),
        SignalInfo("update_checked", java.lang.Boolean::class.java, Integer::class.java, Integer::class.java, Integer::class.java),
        SignalInfo("update_downloaded"),
        SignalInfo("update_failed", String::class.java),
        SignalInfo("games_signed_in", java.lang.Boolean::class.java, String::class.java, String::class.java),
        SignalInfo("cloud_loaded", java.lang.Boolean::class.java, String::class.java, String::class.java),
        SignalInfo("cloud_saved", java.lang.Boolean::class.java, String::class.java),
    )

    private var gamesReady = false

    private fun gamesInit(): android.app.Activity? {
        val a = godot.getActivity() ?: return null
        if (!gamesReady) {
            PlayGamesSdk.initialize(a.applicationContext)
            gamesReady = true
        }
        return a
    }

    private fun reportPlayer(a: android.app.Activity) {
        PlayGames.getPlayersClient(a).currentPlayer.addOnCompleteListener { p ->
            val name = if (p.isSuccessful) p.result?.displayName ?: "" else ""
            emitSignal("games_signed_in", true, name, "")
        }
    }

    /** Was the player signed in automatically at start? Answers with games_signed_in. */
    @UsedByGodot
    fun gamesCheck() {
        val a = gamesInit() ?: return emitSignal("games_signed_in", false, "", "no_activity")
        PlayGames.getGamesSignInClient(a).isAuthenticated.addOnCompleteListener { t ->
            if (t.isSuccessful && t.result?.isAuthenticated == true) reportPlayer(a)
            else emitSignal("games_signed_in", false, "", t.exception?.message ?: "")
        }
    }

    /** Manual sign-in (Settings button). Shows Google's own sign-in sheet. */
    @UsedByGodot
    fun gamesSignIn() {
        val a = gamesInit() ?: return emitSignal("games_signed_in", false, "", "no_activity")
        PlayGames.getGamesSignInClient(a).signIn().addOnCompleteListener { t ->
            if (t.isSuccessful && t.result?.isAuthenticated == true) reportPlayer(a)
            else emitSignal("games_signed_in", false, "", t.exception?.message ?: "cancelled")
        }
    }

    /**
     * Cloud save (Play Games Saved Games, one snapshot). Only after sign-in; the game decides what
     * to keep. Conflicts between two phones resolve to the most recently changed copy here, and
     * the game itself compares progress before it overwrites anything.
     */
    private val snapName = "stone_storm_save"

    @UsedByGodot
    fun cloudLoad() {
        val a = gamesInit() ?: return emitSignal("cloud_loaded", false, "", "no_activity")
        val sc = PlayGames.getSnapshotsClient(a)
        sc.open(snapName, true, SnapshotsClient.RESOLUTION_POLICY_MOST_RECENTLY_MODIFIED).addOnCompleteListener { t ->
            if (!t.isSuccessful) return@addOnCompleteListener emitSignal("cloud_loaded", false, "", t.exception?.message ?: "open_failed")
            val doc = t.result
            val snap = (if (doc.isConflict) doc.conflict?.snapshot else doc.data)
                ?: return@addOnCompleteListener emitSignal("cloud_loaded", false, "", "no_snapshot")
            val text = try { String(snap.snapshotContents.readFully() ?: ByteArray(0), Charsets.UTF_8) } catch (e: Exception) { "" }
            sc.discardAndClose(snap)
            emitSignal("cloud_loaded", true, text, "")
        }
    }

    @UsedByGodot
    fun cloudSave(data: String, description: String) {
        val a = gamesInit() ?: return emitSignal("cloud_saved", false, "no_activity")
        val sc = PlayGames.getSnapshotsClient(a)
        sc.open(snapName, true, SnapshotsClient.RESOLUTION_POLICY_MOST_RECENTLY_MODIFIED).addOnCompleteListener { t ->
            if (!t.isSuccessful) return@addOnCompleteListener emitSignal("cloud_saved", false, t.exception?.message ?: "open_failed")
            val doc = t.result
            val snap = (if (doc.isConflict) doc.conflict?.snapshot else doc.data)
                ?: return@addOnCompleteListener emitSignal("cloud_saved", false, "no_snapshot")
            snap.snapshotContents.writeBytes(data.toByteArray(Charsets.UTF_8))
            val change = SnapshotMetadataChange.Builder().setDescription(description).build()
            sc.commitAndClose(snap, change).addOnCompleteListener { c ->
                emitSignal("cloud_saved", c.isSuccessful, c.exception?.message ?: "")
            }
        }
    }

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

    override fun onMainCreate(activity: android.app.Activity?): android.view.View? {
        // Must run before the first Play Games call; the SDK then signs in by itself.
        if (activity != null) {
            PlayGamesSdk.initialize(activity.applicationContext)
            gamesReady = true
        }
        return super.onMainCreate(activity)
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
