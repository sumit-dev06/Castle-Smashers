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
		return PackedStringArray(["androidx.core:core:1.13.1"])

	func _get_name() -> String:
		return "CastleNotify"
