@tool
extends EditorPlugin
## Packs the CastleFirebase Android plugin (source: tools/android_plugins/firebase).
## Firebase is only compiled in when google-services.json exists (project root, copied into
## android/build by the GodotX Firebase export plugin); without it the export works and the game
## simply sends no analytics. See docs/FIREBASE_SETUP.md.
## SDK versions match GodotX Firebase (push) so the APK carries one Firebase version set.

const GOOGLE_SERVICES: PackedStringArray = ["res://google-services.json", "res://android/build/google-services.json"]

var _export: CastleFirebaseExport


func _enter_tree() -> void:
	_export = CastleFirebaseExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class CastleFirebaseExport extends EditorExportPlugin:
	func _configured() -> bool:
		for f: String in GOOGLE_SERVICES:
			if FileAccess.file_exists(f):
				return true
		return false

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["castle_firebase/bin/castle_firebase.aar"]) if _configured() else PackedStringArray()

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not _configured():
			return PackedStringArray()
		return PackedStringArray(["com.google.firebase:firebase-analytics:23.2.0", "com.google.firebase:firebase-crashlytics:20.1.0", "com.google.firebase:firebase-crashlytics-ndk:20.1.0"])

	func _get_name() -> String:
		return "CastleFirebase"
