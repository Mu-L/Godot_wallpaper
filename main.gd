extends Node2D

# ============================================================================
# 【核心：不要删除】桌面层插件加载
# 这行保证项目在没有 .godot 导入缓存时，也能在首次启动时加载原生插件。
# 删除后 GodotWallPaper 类可能不存在，桌面层功能将无法工作。
# ============================================================================
const DESKTOP_LAYER_EXTENSION = preload(
	"res://addons/godot_wallpaper/godot_wallpaper.gdextension"
)

# 【测试辅助：通常不要修改】只供自动验收使用，不会占用任何游戏按键。
# 如果确定永远不运行自动测试，可以连同 _is_autotest()、_finish_autotest()
# 以及调用它们的代码一起删除，不能只删除其中一部分。
const AUTOTEST_ENVIRONMENT := "DESKTOP_LAYER_TEMPLATE_AUTOTEST"

# 【托盘核心：不要修改】Godot 用 -1 表示托盘图标创建失败或尚未创建。
const INVALID_STATUS_INDICATOR_ID := -1

# ============================================================================
# 【可配置】可以在 Godot 检查器中修改
# auto_enter_desktop：启动后是否自动进入桌面层。
# enter_delay_seconds：等待窗口创建完成后再挂载的时间。建议保持 1 秒；
# 如果某些电脑启动较慢，可以适当增大，不建议设为 0。
# ============================================================================
@export var auto_enter_desktop := true
@export_range(0.1, 10.0, 0.1) var enter_delay_seconds := 1.0

# 【核心：不要删除】原生桌面层对象，由进入、恢复和退出流程共同使用。
var desktop_layer

# 【演示：可以删除】elapsed 只负责让演示图形运动。
# 删除 _process() 和 _draw() 中的演示后，也可以删除这个变量。
var elapsed := 0.0

# 【界面提示：可以修改】可改成自己的状态提示；如果不需要文字，可以删除，
# 但还要同时删除所有对 status_text 的赋值和 _draw() 中对应的 draw_string()。
var status_text := "正在初始化桌面层…"

# 【托盘核心：不要删除】保存托盘菜单、图标 ID 和运行时生成的图像资源。
var tray_menu := RID()
var tray_indicator_id := INVALID_STATUS_INDICATOR_ID
var tray_icon: ImageTexture


# 【核心：不要删除】程序启动入口。
# 顺序很重要：先创建托盘，再加载插件，最后等待并进入桌面层。
func _ready() -> void:
	_create_tray()

	if not ClassDB.class_exists("GodotWallPaper"):
		status_text = "GodotWallPaper 扩展未加载"
		push_error(status_text)
		queue_redraw()
		_finish_autotest(false)
		return

	desktop_layer = ClassDB.instantiate("GodotWallPaper")
	if desktop_layer == null:
		status_text = "GodotWallPaper 创建失败"
		queue_redraw()
		_finish_autotest(false)
		return

	if auto_enter_desktop:
		await get_tree().create_timer(enter_delay_seconds).timeout
		_enter_desktop()
	else:
		status_text = "可通过系统托盘进入桌面层"
		queue_redraw()


# ============================================================================
# 【基础演示：可以全部删除或替换】
# _process() 和 _draw() 只绘制网格、移动圆形、方块和提示文字，
# 与 Windows 桌面层本身无关。制作自己的游戏时，可以：
# 1. 删除这两个函数和 elapsed；或
# 2. 保留桌面层代码，把这里替换成自己的节点、场景和游戏逻辑。
# ============================================================================
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("162438"))
	var grid_color := Color(0.28, 0.48, 0.68, 0.18)
	for x in range(0, int(viewport_size.x) + 64, 64):
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), grid_color, 1.0)
	for y in range(0, int(viewport_size.y) + 64, 64):
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), grid_color, 1.0)

	var moving_center := Vector2(
		viewport_size.x * 0.5 + sin(elapsed * 0.8) * viewport_size.x * 0.32,
		viewport_size.y * 0.5 + cos(elapsed * 1.15) * viewport_size.y * 0.22
	)
	draw_circle(moving_center, 48.0, Color("49c6e5"))
	draw_rect(Rect2(moving_center + Vector2(90, -34), Vector2(68, 68)), Color("ffbd32"))
	for index in 8:
		var angle := elapsed * 0.55 + TAU * index / 8.0
		var orbit := moving_center + Vector2(cos(angle), sin(angle)) * 110.0
		draw_circle(orbit, 8.0, Color("f36f8b"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 54), "Godot Desktop Layer Template", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(36, 86), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.92, 1.0))


# ============================================================================
# 【桌面层核心：不要删除】
# 先分析当前 Windows 桌面结构是否安全，再执行窗口挂载。
# 不要绕过 analyze_reparent_mode() 直接调用 enter_reparent_mode()。
# ============================================================================
func _enter_desktop() -> void:
	if desktop_layer == null:
		return
	var analysis: Dictionary = desktop_layer.analyze_reparent_mode()
	if not analysis.get("safe_to_reparent", false):
		status_text = "无法进入桌面层：%s" % analysis.get("reason", "unknown")
		push_error(status_text)
		queue_redraw()
		_finish_autotest(false)
		return
	var result: Dictionary = desktop_layer.enter_reparent_mode()
	if result.get("success", false):
		status_text = "桌面层运行中 · 可通过系统托盘管理"
		if _is_autotest():
			for frame in 10:
				await get_tree().process_frame
			var verification: Dictionary = desktop_layer.verify_reparent_mode()
			_leave_desktop()
			_finish_autotest(verification.get("correct_layer", false))
	else:
		status_text = "桌面层挂载失败：%s" % result.get("reason", "unknown")
		push_error(status_text)
		_finish_autotest(false)
	queue_redraw()


# 【测试辅助】普通游戏开发不需要调用这两个函数。
func _is_autotest() -> bool:
	return OS.get_environment(AUTOTEST_ENVIRONMENT) == "1"


func _finish_autotest(success: bool) -> void:
	if _is_autotest():
		get_tree().quit(0 if success else 1)


# 【安全恢复核心：绝对不要删除】
# 托盘“恢复”、托盘“退出”和程序关闭都会调用它。
# 删除后，程序退出时可能无法正确恢复窗口的父级、样式、位置和尺寸。
func _leave_desktop() -> void:
	if desktop_layer != null:
		desktop_layer.leave_reparent_mode()
		desktop_layer.leave_desktop_mode()


# ============================================================================
# 【托盘功能：建议保留】
# 这部分只使用 Godot 原生 API，不依赖外部托盘库。
# 菜单文字、提示文字和生成图标的颜色可以自由修改。
# 如果完全不需要托盘，必须成套删除：
# - _ready() 中的 _create_tray()
# - 三个 tray 变量
# - _create_tray()、_destroy_tray() 和三个 _on_tray_*() 回调
# - _exit_tree() 中的 _destroy_tray()
# 不要只删其中一个函数，否则会留下无效回调或未释放的系统资源。
# ============================================================================
func _create_tray() -> void:
	# 【可修改】这里运行时生成纯色图标，避免首次启动依赖导入缓存。
	var tray_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	tray_image.fill(Color("478cbf"))
	tray_icon = ImageTexture.create_from_image(tray_image)

	tray_menu = NativeMenu.create_menu()
	if not tray_menu.is_valid():
		push_warning("系统托盘菜单创建失败")
		return

	NativeMenu.add_item(tray_menu, "进入桌面层", Callable(self, "_on_tray_enter"))
	NativeMenu.add_item(tray_menu, "恢复普通窗口", Callable(self, "_on_tray_restore"))
	NativeMenu.add_separator(tray_menu)
	NativeMenu.add_item(tray_menu, "退出", Callable(self, "_on_tray_exit"))

	tray_indicator_id = DisplayServer.create_status_indicator(
		tray_icon,
		"Godot Desktop Layer Template",
		Callable()
	)
	if tray_indicator_id == INVALID_STATUS_INDICATOR_ID:
		push_warning("系统托盘图标创建失败")
		NativeMenu.free_menu(tray_menu)
		tray_menu = RID()
		return
	DisplayServer.status_indicator_set_menu(tray_indicator_id, tray_menu)


func _destroy_tray() -> void:
	if tray_indicator_id != INVALID_STATUS_INDICATOR_ID:
		DisplayServer.delete_status_indicator(tray_indicator_id)
		tray_indicator_id = INVALID_STATUS_INDICATOR_ID
	if tray_menu.is_valid():
		NativeMenu.free_menu(tray_menu)
		tray_menu = RID()
	tray_icon = null


func _on_tray_enter(_tag = null) -> void:
	_enter_desktop()


func _on_tray_restore(_tag = null) -> void:
	_leave_desktop()
	status_text = "已恢复普通窗口 · 可从托盘再次进入"
	queue_redraw()


func _on_tray_exit(_tag = null) -> void:
	# 【不要改变顺序】必须先恢复 Windows 窗口，再退出程序。
	_leave_desktop()
	get_tree().quit()


# 【退出安全核心：绝对不要删除】
# 即使不是通过托盘退出，也会尝试恢复桌面层并释放托盘资源。
func _exit_tree() -> void:
	_leave_desktop()
	_destroy_tray()

