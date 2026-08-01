@tool
extends EditorPlugin

var _main_screen_dock: EditorDock
var _translation_list: Array[Translation]
var _tracked_project_settings: PackedStringArray
var _project_skip_hack: bool
var _tracked_editor_settings: PackedStringArray

var tr_extract: RefCounted

func set_main_screen_dock(dock: EditorDock) -> void:
	_main_screen_dock = dock
	_main_screen_dock.hide()

func add_plugin_translation(translation: Translation) -> void:
	_translation_list.append(translation)

func add_plugin_translations_from_directory(path: String) -> void:
	for file in ResourceLoader.list_directory(path):
		var translation := load(path.path_join(file)) as Translation
		if translation:
			_translation_list.append(translation)

func register_editor_shortcut(path: String, shortcut_name: String = "", default: int = KEY_NONE) -> Shortcut:
	if EditorInterface.get_editor_settings().has_shortcut(path):
		return EditorInterface.get_editor_settings().get_shortcut(path)
	
	var shortcut := Shortcut.new()
	shortcut.resource_name = shortcut_name
	
	if default != KEY_NONE:
		var event := InputEventKey.new()
		
		if default & KEY_MASK_SHIFT:
			event.shift_pressed = true
		
		if default & KEY_MASK_ALT:
			event.alt_pressed = true
		
		if default & KEY_MASK_CMD_OR_CTRL:
			event.command_or_control_autoremap = true
		else:
			if default & KEY_MASK_CTRL:
				event.ctrl_pressed = true
			
			if default & KEY_MASK_META:
				event.meta_pressed = true
		
		event.keycode = default & KEY_CODE_MASK
		shortcut.events.append(event)
	
	EditorInterface.get_editor_settings().add_shortcut(path, shortcut)
	return shortcut

func define_project_setting(setting: String, default_value: Variant, hint := PROPERTY_HINT_NONE, hint_string := "", basic := false, restart_if_changed := false, internal := false) -> Variant:
	var value: Variant
	if ProjectSettings.has_setting(setting):
		value = ProjectSettings.get_setting(setting)
	else:
		value = default_value
		ProjectSettings.set_setting(setting, default_value)
	
	ProjectSettings.set_initial_value(setting, default_value)
	if hint != PROPERTY_HINT_NONE:
		ProjectSettings.add_property_info({"name": setting, "type": typeof(default_value), "hint": hint, "hint_string": hint_string})
	
	ProjectSettings.set_as_basic(setting, basic)
	ProjectSettings.set_restart_if_changed(setting, restart_if_changed)
	ProjectSettings.set_as_internal(setting, internal)
	
	return value

func define_editor_setting(setting: String, default_value: Variant, hint := PROPERTY_HINT_NONE, hint_string := "") -> Variant:
	var value: Variant
	var editor_settings := EditorInterface.get_editor_settings()
	
	if editor_settings.has_setting(setting):
		value = editor_settings.get_setting(setting)
	else:
		value = default_value
		editor_settings.set_setting(setting, default_value)
	
	editor_settings.set_initial_value(setting, default_value, false)
	if hint != PROPERTY_HINT_NONE:
		editor_settings.add_property_info({"name": setting, "type": typeof(default_value), "hint": hint, "hint_string": hint_string})
	
	return value

func track_project_setting(setting: StringName) -> void:
	_tracked_project_settings.append(setting)
	if not ProjectSettings.settings_changed.is_connected(_check_settings):
		ProjectSettings.settings_changed.connect(_check_settings)
		_project_skip_hack = true
		set_deferred(&"_project_skip_hack" , false)

func track_editor_setting(setting: StringName) -> void:
	_tracked_editor_settings.append(setting)
	var es := EditorInterface.get_editor_settings()
	if not es.settings_changed.is_connected(_check_settings):
		es.settings_changed.connect(_check_settings)

func _check_settings() -> void:
	if _project_skip_hack:
		return
	
	for setting in _tracked_project_settings:
		if ProjectSettings.check_changed_settings_in_group(setting):
			_on_setting_changed(setting, ProjectSettings.get_setting(setting))
			return
	
	var es := EditorInterface.get_editor_settings()
	for setting in _tracked_editor_settings:
		if es.check_changed_settings_in_group(setting):
			_on_setting_changed(setting, es.get_setting(setting))

func _on_setting_changed(setting: String, new_value: Variant) -> void:
	pass

func _has_main_screen() -> bool:
	return _main_screen_dock != null

func _get_plugin_name() -> String:
	if not _main_screen_dock:
		return ""
	if not _main_screen_dock.title.is_empty():
		return _main_screen_dock.title
	return _main_screen_dock.name

func _get_plugin_icon() -> Texture2D:
	if not _main_screen_dock:
		return null
	if _main_screen_dock.dock_icon:
		return _main_screen_dock.dock_icon
	if not _main_screen_dock.icon_name.is_empty():
		return EditorInterface.get_editor_theme().get_icon(_main_screen_dock.icon_name, &"EditorIcons")
	return null

func _make_visible(visible: bool) -> void:
	if _main_screen_dock:
		_main_screen_dock.visible = visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if _main_screen_dock:
			EditorInterface.get_editor_main_screen().add_child(_main_screen_dock)
		
		if not tr_extract:
			tr_extract = RefCounted.new()
			tr_extract.set_message_translation(false)
		
		var domain := TranslationServer.get_or_add_domain(&"godot.editor")
		for translation in _translation_list:
			domain.add_translation(translation)
		
		return
	
	if what == NOTIFICATION_EXIT_TREE:
		if _main_screen_dock:
			_main_screen_dock.queue_free()
		
		var domain := TranslationServer.get_or_add_domain(&"godot.editor")
		for translation in _translation_list:
			domain.remove_translation(translation)
		
		return
