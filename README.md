# Godot WallPaper 桌面层插件与运行模板

Godot WallPaper 是一个面向 **Godot 4.7、Windows 10/11 x86_64** 的原生桌面层插件。本运行版已经包含编译好的 DLL，可以把 Godot 窗口放在系统壁纸之上、桌面图标之下，无需安装 C++ 编译环境。

## 1. 能做什么

- 自动探测 Windows 的 Progman、WorkerW、桌面图标窗口和 Godot 窗口。
- 进入前检查父窗口、进程归属、DPI Awareness 和可用挂载模式。
- 把 Godot 动态画面放到桌面图标下方。
- 保持桌面图标正常显示，不修改或持续刷新图标窗口。
- 保存原始窗口状态，恢复时还原父级、样式、位置和尺寸。
- 使用 Godot 原生 API 提供托盘菜单。

当前限制：

- 仅支持 Windows 10/11 x86_64。
- 第一版主要按主显示器验证。
- Explorer 重启后的自动重新挂载尚未实现。
- 插件负责窗口层级，不自动提供游戏玩法、存档或全局输入。
- 编辑器内嵌游戏窗口不适合挂载，建议使用独立窗口。

## 2. 直接运行模板

### 发布目录

`Godot_wallpaper` 可以单独复制、改名或发布。

```text
Godot_wallpaper/
├─ project.godot
├─ export_presets.cfg
├─ main.tscn
├─ main.gd
└─ addons/
   └─ godot_wallpaper/
      ├─ godot_wallpaper.gdextension
      └─ bin/
         └─ godot_wallpaper.dll
```

这是源码模板的最小独立结构。它不附带、查找或猜测 Godot 引擎文件名，使用者需要自行安装 Godot 4.7。

### 启动步骤

源码模板的运行方式：

1. 启动用户自己安装的 Godot 4.7 项目管理器。
2. 点击“导入”，选择本目录中的 `project.godot`。
3. 打开项目，关闭编辑器的“嵌入游戏窗口”。
4. 点击“运行项目”或按 `F6/F5`，让游戏以独立窗口启动。
5. 等待约 1 秒，让 Godot 原生窗口和 Explorer 桌面窗口准备完成。
6. 看到深色网格和移动几何体后，确认桌面图标仍显示在动画上方。

普通用户不需要导入项目，可以直接进入 `dist/` 并运行：

```text
Godot_wallpaper.exe
```

`godot_wallpaper.dll` 必须与 EXE 保持在同一目录。Godot 的默认运行日志位于 `%APPDATA%\Godot\app_userdata\Godot_wallpaper\logs\godot.log`。

### 托盘控制

程序启动后，通知区域会出现一个蓝色托盘图标。Windows 可能把它放进“隐藏的图标”区域。

- **进入桌面层**：重新分析当前桌面结构并挂载。
- **恢复普通窗口**：把 Godot 恢复为普通窗口。
- **退出**：先恢复窗口，再释放托盘资源并退出。

不要优先使用任务管理器强制结束程序，因为强制终止可能跳过窗口恢复逻辑。正常情况下请从托盘退出。

## 3. 使用模板开发自己的内容

用 Godot 4.7 打开 `wallpaper_runtime/project.godot`。

可以修改或删除：

- `main.gd` 中标记为“基础演示”的 `_process()` 和 `_draw()`。
- 网格、几何体、粒子、动画和状态文字。
- `main.tscn` 中的演示节点。
- 托盘菜单文字、提示文字和图标颜色。
- 项目名称、项目图标和游戏输入。

必须保留：

- `addons/godot_wallpaper/` 整个目录。
- 主脚本顶部对 `.gdextension` 的显式 `preload()`。
- `_enter_desktop()` 进入前的安全分析。
- `_leave_desktop()` 和 `_exit_tree()` 中的窗口恢复。
- 如果保留托盘，必须成套保留托盘变量、创建、回调和销毁函数。

模板的 `main.gd` 已用中文标注哪些区域可以修改、可以删除或必须保留。

## 4. 在全新 Godot 项目中接入插件

### 4.1 创建项目

1. 使用 Godot 4.7 创建项目。
2. 渲染器选择 **Compatibility(兼容)**。
3. 创建并保存主场景。
4. 目标平台使用 Windows x86_64。

建议在 `project.godot` 中启用高 DPI：

```ini
[display]

window/dpi/allow_hidpi=true
```

### 4.2 复制插件

把本模板的整个目录：

```text
addons/godot_wallpaper/
```

复制到新项目根目录。最终结构必须是：

```text
你的项目/
├─ project.godot
├─ 你的主场景.tscn
└─ addons/
   └─ godot_wallpaper/
      ├─ godot_wallpaper.gdextension
      └─ bin/
         └─ godot_wallpaper.dll
```

不要只复制 DLL。DLL 是原生代码本体，`.gdextension` 是 Godot 的加载描述，两者缺一不可。

### 4.3 添加最小控制脚本

把下面的脚本挂到主场景中常驻的根节点。根节点可以是 `Node`、`Node2D` 或其他节点。

```gdscript
extends Node

# 必须保留：保证无 .godot 缓存时也能首次加载插件。
const GODOT_WALLPAPER_EXTENSION = preload(
	"res://addons/godot_wallpaper/godot_wallpaper.gdextension"
)

var desktop_layer


func _ready() -> void:
	if not ClassDB.class_exists("GodotWallPaper"):
		push_error("Godot WallPaper 插件未加载")
		return

	desktop_layer = ClassDB.instantiate("GodotWallPaper")
	if desktop_layer == null:
		push_error("GodotWallPaper 创建失败")
		return

	# 等待 Godot 原生窗口创建完成；慢速电脑可适当增大。
	await get_tree().create_timer(1.0).timeout
	enter_desktop_layer()


func enter_desktop_layer() -> void:
	if desktop_layer == null:
		return

	# 必须先分析，不能绕过安全检查直接挂载。
	var analysis: Dictionary = desktop_layer.analyze_reparent_mode()
	if not analysis.get("safe_to_reparent", false):
		push_error("无法进入桌面层：%s" % analysis.get("reason", "unknown"))
		return

	var result: Dictionary = desktop_layer.enter_reparent_mode()
	if not result.get("success", false):
		push_error("桌面层挂载失败：%s" % result.get("reason", "unknown"))


func leave_desktop_layer() -> void:
	if desktop_layer != null:
		desktop_layer.leave_reparent_mode()
		desktop_layer.leave_desktop_mode()


func _exit_tree() -> void:
	# 必须保留：所有正常退出路径都要恢复 Windows 窗口。
	leave_desktop_layer()
```

### 4.4 使用独立窗口运行

如果从 Godot 编辑器测试，请关闭“嵌入游戏窗口”，确保游戏以独立窗口运行。编辑器创建的附属窗口可能带有 owner，插件会拒绝不安全的挂载。

推荐的最终验证方式：

- 导出 Windows EXE 后直接运行。

### 4.5 验收接入结果

- 游戏画面覆盖桌面背景区域。
- 桌面图标显示在游戏画面上方。
- 动画持续更新，没有静态残影或闪烁。
- 调用恢复后，Godot 重新成为普通窗口。
- 正常退出后，没有新增的残留游戏进程。

## 5. 插件接口

插件向 GDScript 注册类 `GodotWallPaper`。

| 方法 | 作用 | 使用要求 |
|---|---|---|
| `probe()` | 探测平台、Godot HWND 和基础 Shell 窗口 | 排错时使用 |
| `analyze_desktop_layers()` | 返回更详细的 Windows 桌面窗口结构 | 深度诊断时使用 |
| `analyze_reparent_mode()` | 分析宿主、层级、DPI 和挂载安全性 | 每次进入前必须调用 |
| `prepare_reparent_mode()` | 请求 Explorer 准备可用的 WorkerW 结构 | 特定 Shell 结构下使用 |
| `enter_reparent_mode()` | 保存原窗口状态并执行桌面层挂载 | 仅在分析安全后调用 |
| `verify_reparent_mode()` | 验证父窗口、样式、尺寸和 Z-order | 测试或诊断时使用 |
| `refresh_reparent_mode()` | 使用已保存的桌面宿主重新校正尺寸和 Z-order | 层级被托盘或系统激活改变时使用 |
| `leave_reparent_mode()` | 恢复父级、样式、位置和尺寸 | 恢复和退出时必须调用 |
| `is_reparent_mode_active()` | 查询是否处于 reparent 模式 | 状态 UI 可选使用 |

`enter_desktop_mode()` 和 `leave_desktop_mode()` 是早期顶层窗口方案的兼容接口。当前主要方案使用 reparent 模式，但模板恢复时同时调用两种 leave 接口，以覆盖不同状态。

接口返回的 `Dictionary` 至少应这样检查：

```gdscript
if result.get("success", false):
	print("操作成功")
else:
	push_error(result.get("reason", "unknown"))
```

## 6. 插件运行原理

Windows 桌面由 Explorer 的多个窗口组成，并不是一张普通背景图片。常见结构包括：

```text
Progman
├─ SHELLDLL_DefView
│  └─ SysListView32       桌面图标
└─ Godot 窗口             插件选择的挂载位置之一
```

部分系统会使用顶层或子级 `WorkerW`。插件不会保存固定句柄，而是在每次进入前重新枚举当前 Explorer 窗口。

核心流程：

1. 获取当前 Godot 原生窗口句柄。
2. 查找 `Progman`、`WorkerW`、`SHELLDLL_DefView` 和 `SysListView32`。
3. 验证窗口有效性、Shell 进程归属、相对 Z-order 和 DPI Awareness。
4. 保存 Godot 原始父窗口、样式、扩展样式、位置和尺寸。
5. Windows 11 Raised Desktop 模式下，在 `SetParent` 前添加 `WS_EX_LAYERED` 并设置 alpha 255。
6. 通过 Win32 `SetParent` 把 Godot 挂入正确的桌面宿主。
7. 把 Godot 放到桌面图标宿主之后。
8. 再次验证父窗口、layered 属性、客户区和相对层级。
9. 离开或退出时恢复步骤 4 保存的全部状态。

透明背景只决定像素如何合成，不能代替正确的窗口层级。这个插件的核心是选择正确的 Explorer 宿主和 Z-order，而不是简单设置窗口透明。

## 7. 插件文件说明

```text
addons/godot_wallpaper/
├─ godot_wallpaper.gdextension
└─ bin/
   └─ godot_wallpaper.dll
```

### `godot_wallpaper.dll`

- 编译后的原生插件本体。
- 包含 GDExtension 注册和 Win32 桌面层实现。
- 当前适用于 Windows x86_64。
- Debug 与 Release Godot 运行模式共用这个正式 DLL。
- 不能使用文本编辑器修改。

### `godot_wallpaper.gdextension`

- Godot 的插件加载描述文件。
- 定义 DLL 路径、最低兼容版本和入口符号。
- 入口符号是 `godot_wallpaper_library_init`，它是内部 ABI 名称，不需要与展示名称相同。
- 不要删除或随意修改 DLL 路径和入口符号。

## 8. 托盘功能与插件的关系

托盘由模板的 `main.gd` 使用 Godot 原生 `DisplayServer` 和 `NativeMenu` 创建，不是 DLL 自动生成的。

因此：

- 仅复制插件到新项目不会自动出现托盘。
- 需要托盘时，可以复用模板的 `_create_tray()`、`_destroy_tray()` 和 `_on_tray_*()`。
- 不需要托盘时，可以成套删除托盘代码，不影响 DLL 的桌面层功能。
- NativeMenu 回调中不要直接恢复、销毁菜单或退出；模板使用 `call_deferred()`，等原生菜单回调返回后再执行操作，避免重入卡死。
- 托盘可能短暂激活宿主窗口。模板每 0.5 秒验证桌面层，只在 Z-order 或尺寸异常时调用 `refresh_reparent_mode()` 自动纠正。
- 延迟执行的退出流程必须先恢复桌面层，再调用 `get_tree().quit()`。

## 9. 游戏交互注意事项

桌面图标窗口位于游戏画面上方，因此普通鼠标事件会优先交给图标层。这是桌面图标仍可正常操作的原因。

建议：

- 使用低频、环境式、挂机式或间歇交互玩法。
- 不要假设整个桌面区域都能收到 Godot 普通鼠标点击。
- 复杂交互可以通过托盘打开普通设置窗口或游戏面板。
- 具体游戏自行定义键盘输入，模板不抢占按键。
- 不要通过修改或逐帧刷新 `SysListView32` 获取点击，这会导致图标异常或桌面闪烁。

## 10. 常见问题

### 双击后看起来没有运行

Godot 可能已经进入桌面层。检查动态网格、通知区域的蓝色托盘图标、任务管理器和 Godot 默认运行日志。

### 双击后只看到空窗口

打开 `%APPDATA%\Godot\app_userdata\Godot_wallpaper\logs\godot.log`，检查 `SCRIPT ERROR` 或 `Failed loading resource`。当前模板的托盘图标由代码生成，不依赖 SVG 导入缓存。

### 显示“扩展未加载”

确认以下文件都存在：

```text
addons/godot_wallpaper/godot_wallpaper.gdextension
addons/godot_wallpaper/bin/godot_wallpaper.dll
```

同时确认使用 Godot 4.7 和 Windows x86_64，插件目录不能多套或少套一层。

### 编辑器运行时提示窗口存在 owner

这是安全检查在阻止不可靠挂载。关闭编辑器的嵌入运行功能，使用独立窗口或导出程序测试。

### 托盘图标没有显示

展开 Windows 的隐藏图标区域。托盘来自 `main.gd`，如果使用自己的控制脚本，需要自行实现或复制托盘代码。

### 画面或图标层级不正确

先从托盘恢复窗口。不要修改桌面 ListView 的透明样式或逐帧刷新它。可以重启 Explorer 或重新登录后再次测试，并保留日志用于诊断。

### 如何安全停止程序

优先选择托盘的“退出”。如果只能强制结束，Windows 可能来不及执行窗口恢复；必要时可重启 Explorer 恢复桌面状态。

## 11. 发布自己的游戏

有两种独立发布方式：

### 发布源码模板

直接发布整个 `Godot_wallpaper/` 项目目录。接收者自行安装 Godot 4.7，然后在项目管理器中导入 `project.godot`。模板不依赖 Godot 可执行文件的名称或安装位置。

### 发布可直接运行的游戏

1. 使用 Godot 4.7 Windows x86_64 导出项目，主程序命名为 `Godot_wallpaper.exe`。
2. 当前预设把 PCK 嵌入 EXE，成品目录只需 `Godot_wallpaper.exe` 和同目录的 `godot_wallpaper.dll`。
3. 普通用户直接双击 `Godot_wallpaper.exe`，不需要安装 Godot，也不需要运行脚本。
4. 使用独立游戏窗口，不依赖编辑器内嵌运行。
5. 至少在一台 Windows 10 和一台 Windows 11 电脑上验证。
6. 测试进入、恢复、托盘退出、Explorer 重启和系统注销路径。
7. 正式发布时建议为 EXE 和 DLL 添加代码签名，减少未知程序警告。

运行版不包含重新编译能力。修改 C++ 实现时，请使用同级完整开发项目 `wallpaper/`。

## 12. 最终检查清单

- [ ] `project.godot` 指向正确的主场景。
- [ ] 主脚本显式 preload `godot_wallpaper.gdextension`。
- [ ] `.gdextension` 和 `bin/godot_wallpaper.dll` 均存在。
- [ ] 使用 Godot 4.7、Compatibility renderer 和 Windows x86_64。
- [ ] 每次进入前调用 `analyze_reparent_mode()`。
- [ ] 所有正常退出路径都调用恢复函数。
- [ ] 模板没有占用具体游戏需要的键盘按键。
- [ ] 托盘能够进入、恢复和安全退出。
- [ ] 桌面图标正常显示且没有闪烁。
- [ ] 在删除 `.godot` 缓存的副本中完成首次启动测试。


