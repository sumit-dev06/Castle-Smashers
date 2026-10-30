@tool
extends EditorPlugin
## Packs the CastleFirebase Android plugin (source: tools/android_plugins/firebase).
## Firebase is only compiled in when res://android/build/google-services.json exists; without it
## the export works and the game simply sends no analytics. See docs/FIREBASE_SETUP.md.

const GOOGLE_SERVICES: String = "res://android/build/google-services.json"

var _export: CastleFirebaseExport


func _enter_tree() -> void:
	_export = CastleFirebaseExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class CastleFirebaseExport extends EditorExportPlugin:
	func _configured() -> bool:
		return FileAccess.file_exists(GOOGLE_SERVICES)

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["castle_firebase/bin/castle_firebase.aar"]) if _configured() else PackedStringArray()

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not _configured():
			return PackedStringArray()
		return PackedStringArray(["com.google.firebase:firebase-analytics:22.1.2", "com.google.firebase:firebase-crashlytics:19.3.0", "com.google.firebase:firebase-crashlytics-ndk:19.3.0"])

	func _get_name() -> String:
		return "CastleFirebase"
