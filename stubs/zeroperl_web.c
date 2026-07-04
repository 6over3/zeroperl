// zeroperl_web.c — Async Web APIs (fetch and sleep) for zeroperl
//
// Registers two Perl-callable functions backed by host async handlers:
//   main::fetch($url, \%options)  — host function ID 1001
//   main::sleep($ms)              — host function ID 1002
//
// Must be called after zeroperl_init() and before running Perl code.
// The JavaScript host must register matching handlers for IDs 1001 and 1002.

#include <stdint.h>

#if defined(__WASI__) || defined(__wasi__)
#define ZEROPERL_API(name) \
    __attribute__((export_name(name))) __attribute__((visibility("default")))
#else
#define ZEROPERL_API(name) __attribute__((visibility("default")))
#endif

#define ZEROPERL_WEB_FETCH_ID 1001
#define ZEROPERL_WEB_SLEEP_ID 1002

// Defined in zeroperl.c — registers a Perl XSUB that dispatches to the host
// via host_call_function(func_id, argc, argv) using asyncify suspension.
extern void zeroperl_register_function(int32_t func_id, const char *name);

//! Register async web APIs as Perl-callable functions.
//! After calling this, Perl code may use fetch() and sleep() directly.
ZEROPERL_API("zeroperl_init_web_apis")
void zeroperl_init_web_apis(void) {
    zeroperl_register_function(ZEROPERL_WEB_FETCH_ID, "main::fetch");
    zeroperl_register_function(ZEROPERL_WEB_SLEEP_ID, "main::sleep");
}
