@tool
extends EditorPlugin
## Packs the CastleNotify Android plugin (source: tools/android_plugins/notify).

var _export: CastleNotifyExport


func _enter_tree() -> void:
	_export = CastleNotifyExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class CastleNotifyExport extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["castle_notify/bin/castle_notify.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.13.1", "com.google.android.play:review:2.0.2", "com.google.android.play:app-update:2.1.0"])

	## Firebase Cloud Messaging pushes (GodotX Firebase) use the same white castle small icon and the
	## same "Siege reminders" channel as local reminders, so one Settings switch covers both.
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return ('<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@mipmap/icon_monochrome" />\n'
				+ '<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="castle_reminders" />\n'
				# Ads fill the whole screen, camera cutout included (Theme.CastleAd lives in castle_notify.aar).
				+ '<activity android:name="com.google.android.libraries.ads.mobile.sdk.common.AdActivity" android:theme="@style/Theme.CastleAd" tools:replace="android:theme" />\n'
				# Play Billing opens its purchase sheet from these see-through activities. They declare no
				# orientation, so on a phone with auto-rotate off Android turned the whole game to portrait.
				+ '<activity android:name="com.android.billingclient.api.ProxyBillingActivity" android:screenOrientation="sensorLandscape" />\n'
				+ '<activity android:name="com.android.billingclient.api.ProxyBillingActivityV2" android:screenOrientation="sensorLandscape" />\n')

	func _get_name() -> String:
		return "CastleNotify"
