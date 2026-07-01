// mcp_bridge.m - C bridge for ios-mcp dylib
// 将 ios-mcp 的 Objective-C 管理器封装为 C 函数供 Go (CGO) 调用
//
// 编译方式 (在 ios-mcp 源码目录中):
//   clang -arch arm64 -dynamiclib -o libmcp.dylib \
//       mcp_bridge.m HIDManager.m ScreenManager.m AppManager.m \
//       AccessibilityManager.m ClipboardManager.m TextInputManager.m \
//       FileSystemManager.m LogManager.m OCRManager.m \
//       MCPServer.m MCPAXNodeSource.m MCPUIElementSerializer.m \
//       MCPUIElementsFacade.m MCPProcessUtil.m MCPLogger.m \
//       MCPAXAttributeBridge.m MCPAXQueryContext.m \
//       MCPAXRemoteContextResolver.m \
//       -framework UIKit -framework Foundation -framework QuartzCore \
//       -framework IOKit -framework CoreGraphics \
//       -install_name @rpath/libmcp.dylib \
//       -mios-version-min=14.0 \
//       -fobjc-arc

#import "mcp_bridge.h"

// ========== ios-mcp Manager Imports ==========
// 这些头文件来自 witchan/ios-mcp 项目，编译时需要将其源码放在同一目录
#import "HIDManager.h"
#import "ScreenManager.h"
#import "AppManager.h"
#import "AccessibilityManager.h"
#import "ClipboardManager.h"
#import "TextInputManager.h"
#import "FileSystemManager.h"
#import "LogManager.h"
#import "OCRManager.h"
#import "MCPServer.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>
#include <stdlib.h>

// ============================================================
// JSON 序列化辅助
// ============================================================
static NSString* mcp_json(NSDictionary* dict) {
    if (!dict) return nil;
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
    if (err) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// ============================================================
// 初始化
// ============================================================
void mcp_init(void) {
    // 所有 Manager 都是单例，首次调用时自动初始化
    dispatch_sync(dispatch_get_main_queue(), ^{
        [ScreenManager sharedInstance];
        [IOSMCPHIDManager sharedInstance];
        [AppManager sharedInstance];
        [AccessibilityManager sharedInstance];
        [ClipboardManager sharedInstance];
        [TextInputManager sharedInstance];
        [FileSystemManager sharedInstance];
        [LogManager sharedInstance];
        [OCRManager sharedInstance];
    });
}

char* mcp_version(void) {
    return strdup("1.2.1");
}

// ============================================================
// 触摸操作
// ============================================================
static int mcp_hid_sync(dispatch_block_t block) {
    __block BOOL ok = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
        ok = YES;
        dispatch_semaphore_signal(sem);
    });
    
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return ok ? 0 : -1;
}

int mcp_tap(double x, double y) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] tapAtPoint:CGPointMake(x, y)
                                           completion:^(BOOL s, NSString* e) {}];
    });
}

int mcp_long_press(double x, double y, double duration_ms) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] longPressAtPoint:CGPointMake(x, y)
                                                   duration:duration_ms
                                                 completion:^(BOOL s, NSString* e) {}];
    });
}

int mcp_double_tap(double x, double y, double interval_ms) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] doubleTapAtPoint:CGPointMake(x, y)
                                                   interval:interval_ms
                                                 completion:^(BOOL s, NSString* e) {}];
    });
}

int mcp_swipe(double from_x, double from_y, double to_x, double to_y,
              double duration_ms, int steps) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] swipeFromPoint:CGPointMake(from_x, from_y)
                                                  toPoint:CGPointMake(to_x, to_y)
                                                 duration:duration_ms
                                                    steps:steps < 2 ? 10 : steps
                                               completion:^(BOOL s, NSString* e) {}];
    });
}

int mcp_drag(double from_x, double from_y, double to_x, double to_y,
             double hold_ms, double move_ms, int steps) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] dragFromPoint:CGPointMake(from_x, from_y)
                                                 toPoint:CGPointMake(to_x, to_y)
                                             holdDuration:hold_ms
                                             moveDuration:move_ms
                                                    steps:steps < 2 ? 10 : steps
                                               completion:^(BOOL s, NSString* e) {}];
    });
}

// ============================================================
// 硬件按键
// ============================================================
static int mcp_press_button(HIDButtonType button, double duration_ms) {
    return mcp_hid_sync(^{
        [[IOSMCPHIDManager sharedInstance] pressButton:button
                                              duration:duration_ms
                                            completion:^(BOOL s, NSString* e) {}];
    });
}

int mcp_press_home(double duration_ms)       { return mcp_press_button(HIDButtonHome, duration_ms); }
int mcp_press_power(double duration_ms)      { return mcp_press_button(HIDButtonPower, duration_ms); }
int mcp_press_volume_up(double duration_ms)  { return mcp_press_button(HIDButtonVolumeUp, duration_ms); }
int mcp_press_volume_down(double duration_ms){ return mcp_press_button(HIDButtonVolumeDown, duration_ms); }
int mcp_toggle_mute(void)                    { return mcp_press_button(HIDButtonMute, 100); }

int mcp_wake_and_home(void) {
    mcp_press_power(100);
    usleep(100000); // 100ms
    return mcp_press_home(100);
}

// ============================================================
// 屏幕截图
// ============================================================
char* mcp_screenshot_png(void) {
    __block NSString* result = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSDictionary* payload = [[ScreenManager sharedInstance] takeScreenshotPayload];
        NSString* data = payload[@"data"];
        if ([data isKindOfClass:[NSString class]]) {
            result = data;
        }
    });
    return result ? strdup([result UTF8String]) : NULL;
}

char* mcp_screenshot_jpeg(double quality) {
    // ScreenManager 默认返回 PNG/JPEG Base64，通过 takeScreenshotPayload 获取
    return mcp_screenshot_png(); // 简化：统一返回截图
}

char* mcp_screen_info(void) {
    __block NSDictionary* info = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        info = [[ScreenManager sharedInstance] screenInfo];
    });
    if (!info) return NULL;
    NSString* json = mcp_json(info);
    return json ? strdup([json UTF8String]) : NULL;
}

// ============================================================
// 文字输入
// ============================================================
int mcp_input_text(const char* text) {
    if (!text) return -1;
    NSString* str = [NSString stringWithUTF8String:text];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        ok = [[TextInputManager sharedInstance] inputTextViaClipboard:str];
    });
    return ok ? 0 : -1;
}

int mcp_type_text(const char* text) {
    if (!text) return -1;
    NSString* str = [NSString stringWithUTF8String:text];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        ok = [[TextInputManager sharedInstance] typeTextViaHID:str];
    });
    return ok ? 0 : -1;
}

int mcp_press_key(const char* key_name) {
    if (!key_name) return -1;
    NSString* key = [NSString stringWithUTF8String:key_name];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        ok = [[TextInputManager sharedInstance] pressKey:key];
    });
    return ok ? 0 : -1;
}

// ============================================================
// 应用管理
// ============================================================
int mcp_launch_app(const char* bundle_id) {
    if (!bundle_id) return -1;
    NSString* bid = [NSString stringWithUTF8String:bundle_id];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* err = nil;
        ok = [[AppManager sharedInstance] launchApp:bid error:&err];
    });
    return ok ? 0 : -1;
}

int mcp_kill_app(const char* bundle_id) {
    if (!bundle_id) return -1;
    NSString* bid = [NSString stringWithUTF8String:bundle_id];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* err = nil;
        ok = [[AppManager sharedInstance] killApp:bid error:&err];
    });
    return ok ? 0 : -1;
}

char* mcp_frontmost_app(void) {
    __block NSDictionary* app = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        app = [[AppManager sharedInstance] getFrontmostApp];
    });
    if (!app) return NULL;
    NSString* json = mcp_json(app);
    return json ? strdup([json UTF8String]) : NULL;
}

char* mcp_list_apps(const char* type) {
    NSString* t = type ? [NSString stringWithUTF8String:type] : @"all";
    __block NSArray* apps = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        apps = [[AppManager sharedInstance] listInstalledApps:t];
    });
    if (!apps) return NULL;
    NSString* json = mcp_json(@{@"apps": apps});
    return json ? strdup([json UTF8String]) : NULL;
}

char* mcp_app_info(const char* bundle_id) {
    if (!bundle_id) return NULL;
    NSString* bid = [NSString stringWithUTF8String:bundle_id];
    __block NSDictionary* info = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* err = nil;
        info = [[AppManager sharedInstance] appInfoForBundleId:bid error:&err];
    });
    if (!info) return NULL;
    NSString* json = mcp_json(info);
    return json ? strdup([json UTF8String]) : NULL;
}

// ============================================================
// 剪贴板
// ============================================================
char* mcp_get_clipboard(void) {
    __block NSString* text = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        text = [[ClipboardManager sharedInstance] getClipboard];
    });
    return text ? strdup([text UTF8String]) : NULL;
}

int mcp_set_clipboard(const char* text) {
    if (!text) return -1;
    NSString* str = [NSString stringWithUTF8String:text];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[ClipboardManager sharedInstance] setClipboard:str];
    });
    return 0;
}

// ============================================================
// 设备信息 & 控制
// ============================================================
char* mcp_device_info(void) {
    // 使用 UIDevice 获取基本信息
    UIDevice* device = [UIDevice currentDevice];
    NSDictionary* info = @{
        @"name":       device.name ?: @"",
        @"model":      device.model ?: @"",
        @"system":     device.systemName ?: @"",
        @"version":    device.systemVersion ?: @"",
        @"identifier": device.identifierForVendor.UUIDString ?: @"",
    };
    NSString* json = mcp_json(info);
    return json ? strdup([json UTF8String]) : NULL;
}

double mcp_get_brightness(void) {
    __block double b = 0.5;
    dispatch_sync(dispatch_get_main_queue(), ^{
        b = [UIScreen mainScreen].brightness;
    });
    return b;
}

int mcp_set_brightness(double level) {
    if (level < 0) level = 0;
    if (level > 1) level = 1;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [UIScreen mainScreen].brightness = (CGFloat)level;
    });
    return 0;
}

double mcp_get_volume(void) {
    // 通过 MPAVolumeView 或私有 API 获取
    // 简化实现，实际应使用 AVSystemController
    return 0.5;
}

int mcp_set_volume(double level) {
    // iOS 音量需要通过私有框架设置
    // 简化：发送音量键事件模拟
    (void)level;
    return -1; // 需要私有 API，先返回不支持
}

// ============================================================
// UI 元素
// ============================================================
char* mcp_ui_elements(void) {
    __block NSArray* elements = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        elements = [[AccessibilityManager sharedInstance] fetchCompactElementsClickableOnly:NO];
    });
    if (!elements) return NULL;
    NSString* json = mcp_json(@{@"elements": elements});
    return json ? strdup([json UTF8String]) : NULL;
}

char* mcp_element_at_point(double x, double y) {
    __block NSDictionary* element = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        element = [[AccessibilityManager sharedInstance] elementAtPoint:CGPointMake(x, y)];
    });
    if (!element) return NULL;
    NSString* json = mcp_json(element);
    return json ? strdup([json UTF8String]) : NULL;
}

int mcp_tap_element(const char* text, const char* match_mode) {
    if (!text) return -1;
    NSString* t = [NSString stringWithUTF8String:text];
    NSString* mode = match_mode ? [NSString stringWithUTF8String:match_mode] : @"contains";
    
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSArray* elements = [[AccessibilityManager sharedInstance] fetchCompactElementsClickableOnly:YES];
        for (NSDictionary* el in elements) {
            NSString* label = el[@"label"];
            if (!label) continue;
            BOOL match = NO;
            if ([mode isEqualToString:@"exact"]) {
                match = [label isEqualToString:t];
            } else {
                match = [label rangeOfString:t options:NSCaseInsensitiveSearch].location != NSNotFound;
            }
            if (match) {
                CGFloat x = [el[@"x"] doubleValue] + [el[@"width"] doubleValue] / 2.0;
                CGFloat y = [el[@"y"] doubleValue] + [el[@"height"] doubleValue] / 2.0;
                [[IOSMCPHIDManager sharedInstance] tapAtPoint:CGPointMake(x, y)
                                                   completion:^(BOOL s, NSString* e) {}];
                ok = YES;
                break;
            }
        }
    });
    return ok ? 0 : -1;
}

char* mcp_wait_for_element(const char* text, const char* match_mode, double timeout_sec) {
    // 简化实现：轮询等待元素出现
    if (!text) return NULL;
    
    NSString* t = [NSString stringWithUTF8String:text];
    NSString* mode = match_mode ? [NSString stringWithUTF8String:match_mode] : @"contains";
    __block NSDictionary* found = nil;
    
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:timeout_sec];
    while ([deadline timeIntervalSinceNow] > 0) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSArray* elements = [[AccessibilityManager sharedInstance] fetchCompactElementsClickableOnly:YES];
            for (NSDictionary* el in elements) {
                NSString* label = el[@"label"];
                if (!label) continue;
                BOOL match = [mode isEqualToString:@"exact"]
                    ? [label isEqualToString:t]
                    : [label rangeOfString:t options:NSCaseInsensitiveSearch].location != NSNotFound;
                if (match) {
                    found = el;
                    break;
                }
            }
        });
        if (found) break;
        usleep(200000); // 200ms
    }
    
    if (!found) return NULL;
    NSString* json = mcp_json(found);
    return json ? strdup([json UTF8String]) : NULL;
}

// ============================================================
// 文件系统
// ============================================================
char* mcp_list_dir(const char* path) {
    if (!path) return NULL;
    __block NSString* result = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* p = [NSString stringWithUTF8String:path];
        result = [[FileSystemManager sharedInstance] listDirectory:p];
    });
    return result ? strdup([result UTF8String]) : NULL;
}

char* mcp_read_file(const char* path) {
    if (!path) return NULL;
    __block NSString* result = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* p = [NSString stringWithUTF8String:path];
        result = [[FileSystemManager sharedInstance] readFile:p];
    });
    return result ? strdup([result UTF8String]) : NULL;
}

int mcp_write_file(const char* path, const char* content) {
    if (!path || !content) return -1;
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* p = [NSString stringWithUTF8String:path];
        NSString* c = [NSString stringWithUTF8String:content];
        ok = [[FileSystemManager sharedInstance] writeFile:p content:c];
    });
    return ok ? 0 : -1;
}

// ============================================================
// 其他
// ============================================================
int mcp_open_url(const char* url_string) {
    if (!url_string) return -1;
    NSString* urlStr = [NSString stringWithUTF8String:url_string];
    __block BOOL ok = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString* err = nil;
        ok = [[AppManager sharedInstance] openURL:urlStr error:&err];
    });
    return ok ? 0 : -1;
}

char* mcp_run_command(const char* command) {
    if (!command) return NULL;
    // 通过 NSTask 执行（越狱环境可用）
    NSString* cmd = [NSString stringWithUTF8String:command];
    NSString* tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"mcp_cmd_%u.sh", arc4random()]];
    [[NSString stringWithFormat:@"%@ 2>&1", cmd] writeToFile:tmpPath
                                                  atomically:YES
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    
    FILE* pipe = popen([[@"sh " stringByAppendingString:tmpPath] UTF8String], "r");
    if (!pipe) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        return NULL;
    }
    
    NSMutableData* data = [NSMutableData data];
    char buf[4096];
    while (fgets(buf, sizeof(buf), pipe)) {
        [data appendBytes:buf length:strlen(buf)];
    }
    pclose(pipe);
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    
    NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output ? strdup([output UTF8String]) : NULL;
}

// ============================================================
// 工具函数
// ============================================================
void mcp_free_string(char* str) {
    if (str) free(str);
}
