// roothide.h - Stub for non-roothide compilation
// Provides minimal declarations needed for libmcp.dylib build

#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Returns the jailbreak root path (e.g., /var/jb)
NSString* jbroot(NSString* path);

// Returns the rootfs path
NSString* rootfs(NSString* path);

// Skip the jbroot prefix if present
NSString* jbroot_skip(NSString* path);

// Returns jbroot prefix
NSString* jbroot_prefix(void);

#ifdef __cplusplus
}
#endif

#endif // ROOTHIDE_H
