// mcp_bridge.h - ios-mcp C API for autogo (CGO)
// 基于 https://github.com/witchan/ios-mcp
// 编译为 dylib 供 Go 端通过 CGO 调用

#ifndef MCP_BRIDGE_H
#define MCP_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// 初始化 & 版本
// ============================================================

// 初始化 mcp 服务（注册所有 manager）
void mcp_init(void);

// 获取版本号，返回的字符串需要调用 mcp_free_string 释放
char* mcp_version(void);

// ============================================================
// 触摸 & 手势操作
// ============================================================

// 单击屏幕坐标 (x, y)，返回 0 成功，-1 失败
int mcp_tap(double x, double y);

// 长按屏幕坐标 (x, y)，duration 毫秒
int mcp_long_press(double x, double y, double duration_ms);

// 双击屏幕坐标 (x, y)，interval 毫秒（两次点击间隔）
int mcp_double_tap(double x, double y, double interval_ms);

// 滑动：从 (from_x, from_y) 到 (to_x, to_y)，duration 毫秒，steps 步数
int mcp_swipe(double from_x, double from_y, double to_x, double to_y,
              double duration_ms, int steps);

// 拖拽：先长按 hold_ms，再移动到目标，move_ms 移动耗时
int mcp_drag(double from_x, double from_y, double to_x, double to_y,
             double hold_ms, double move_ms, int steps);

// ============================================================
// 硬件按键
// ============================================================

int mcp_press_home(double duration_ms);
int mcp_press_power(double duration_ms);
int mcp_press_volume_up(double duration_ms);
int mcp_press_volume_down(double duration_ms);
int mcp_toggle_mute(void);
int mcp_wake_and_home(void);

// ============================================================
// 屏幕截图
// ============================================================

// 截图并返回 PNG 格式 Base64 字符串，调用者需 mcp_free_string 释放
char* mcp_screenshot_png(void);

// 截图返回 JPEG Base64，quality 0.0~1.0
char* mcp_screenshot_jpeg(double quality);

// 获取屏幕信息 JSON 字符串：{width, height, scale, orientation}
char* mcp_screen_info(void);

// ============================================================
// 文字输入
// ============================================================

// 通过剪贴板输入文字
int mcp_input_text(const char* text);

// 逐字符 HID 模拟输入（更真实但慢）
int mcp_type_text(const char* text);

// 点击键盘按键（如 "return", "backspace" 等）
int mcp_press_key(const char* key_name);

// ============================================================
// 应用管理
// ============================================================

int mcp_launch_app(const char* bundle_id);
int mcp_kill_app(const char* bundle_id);

// 返回当前前台应用 JSON 信息
char* mcp_frontmost_app(void);

// 返回已安装应用列表 JSON，type: "user"/"system"/"all"
char* mcp_list_apps(const char* type);

// 获取应用详细信息 JSON（沙盒路径、版本、entitlements 等）
char* mcp_app_info(const char* bundle_id);

// ============================================================
// 剪贴板
// ============================================================

char* mcp_get_clipboard(void);
int mcp_set_clipboard(const char* text);

// ============================================================
// 设备信息 & 控制
// ============================================================

// 获取设备信息 JSON（型号、系统版本、电池、存储等）
char* mcp_device_info(void);

double mcp_get_brightness(void);
int    mcp_set_brightness(double level);   // 0.0 ~ 1.0

double mcp_get_volume(void);
int    mcp_set_volume(double level);       // 0.0 ~ 1.0

// ============================================================
// 无障碍 / UI 元素
// ============================================================

// 获取当前屏幕 UI 元素树 JSON
char* mcp_ui_elements(void);

// 获取指定坐标的 UI 元素
char* mcp_element_at_point(double x, double y);

// 点击匹配文字的 UI 元素
int mcp_tap_element(const char* text, const char* match_mode);

// 等待元素出现，timeout 秒，返回 JSON 信息
char* mcp_wait_for_element(const char* text, const char* match_mode, double timeout_sec);

// ============================================================
// 文件系统
// ============================================================

// 列出目录，返回 JSON
char* mcp_list_dir(const char* path);

// 读取文本文件内容
char* mcp_read_file(const char* path);

// 写文件，返回 0 成功
int mcp_write_file(const char* path, const char* content);

// ============================================================
// 其他
// ============================================================

// 打开 URL / URL Scheme
int mcp_open_url(const char* url_string);

// 执行 shell 命令，返回输出
char* mcp_run_command(const char* command);

// ============================================================
// 工具函数
// ============================================================

// 释放由 mcp_* 返回的字符串（防止内存泄漏）
void mcp_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif // MCP_BRIDGE_H
