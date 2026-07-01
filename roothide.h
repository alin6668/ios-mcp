// roothide.h - Inline implementations for non-roothide jailbreak
// On palera1n/checkra1n/etc. without roothide, paths are direct (no /var/jb prefix)

#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#import <Foundation/Foundation.h>
#include <spawn.h>
#include <sys/wait.h>

#ifdef __cplusplus
extern "C" {
#endif

// Direct jailbreak: paths are at their real filesystem locations
static inline NSString* jbroot(NSString* path) {
    return path;
}

static inline NSString* rootfs(NSString* path) {
    // Check if path exists under /var/jb, otherwise return as-is
    if ([path hasPrefix:@"/var/jb"]) {
        NSString* stripped = [path substringFromIndex:7];
        if (stripped.length == 0) stripped = @"/";
        return stripped;
    }
    return path;
}

static inline NSString* jbroot_skip(NSString* path) {
    // No-op on non-roothide: paths are already real
    return path;
}

static inline NSString* jbroot_prefix(void) {
    // No prefix needed on non-roothide
    return @"";
}

// posix_spawn with proper PATH for jailbreak environments
static inline pid_t jb_posix_spawn(const char* path, char* const argv[]) {
    pid_t pid = 0;
    char* envp[] = {
        "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin",
        "HOME=/var/root",
        NULL
    };
    int ret = posix_spawn(&pid, path, NULL, NULL, argv, envp);
    if (ret != 0) return -1;
    int status;
    waitpid(pid, &status, 0);
    return pid;
}

#ifdef __cplusplus
}
#endif

#endif // ROOTHIDE_H
