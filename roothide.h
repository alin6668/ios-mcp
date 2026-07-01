// roothide.h - Stub for non-roothide compilation
// Provides minimal declarations needed for libmcp.dylib build

#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#ifdef __cplusplus
extern "C" {
#endif

// Returns the jailbreak root path (e.g., /var/jb)
const char* jbroot(const char* path);

// Returns the rootfs path
const char* rootfs(const char* path);

// Skip the jbroot prefix if present
const char* jbroot_skip(const char* path);

// Returns jbroot prefix
const char* jbroot_prefix(void);

#ifdef __cplusplus
}
#endif

#endif // ROOTHIDE_H
