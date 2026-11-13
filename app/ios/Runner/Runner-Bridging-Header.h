#import "GeneratedPluginRegistrant.h"

#include <ifaddrs.h>
#include <net/if.h>
#include <stdint.h>

// Rust core (core/src/ffi.rs), statically linked with -force_load. Dart reaches nv_call through
// DynamicLibrary.process(); Swift uses the key functions for the Face ID / Touch ID path.
char *nv_call(const char *req);
void nv_free(char *p);
int32_t nv_master_for_seal(uint8_t *out);
char *nv_open_with_key(const char *dir, const uint8_t *key, uintptr_t len);
int32_t nv_check_key(const uint8_t *key, uintptr_t len);
