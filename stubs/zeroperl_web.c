/*
 * zeroperl_web.c - Asynchronous Web API stubs for ZeroPerl
 *
 * Provides: fetch($url), fetch_json($url), fetch_post($url, $body, $content_type),
 *           sleep($seconds)
 *
 * WASM host imports expected:
 *   env.host_fetch(url, &out_len) -> ptr
 *   env.host_fetch_post(url, body, ct, &out_len) -> ptr  
 *   env.host_sleep_ms(ms) -> void
 */

#include "EXTERN.h"
#include "XSUB.h"
#include "perl.h"
#include "asyncify.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#if defined(__WASI__) || defined(__wasi__)
#define WEB_API(name) __attribute__((export_name(name))) __attribute__((visibility("default")))
#define WEB_IMPORT(name) __attribute__((import_module("env"))) __attribute__((import_name(name)))
#else
#define WEB_API(name) __attribute__((visibility("default")))
#define WEB_IMPORT(name)
#endif

/* WASM host imports */
WEB_IMPORT("host_fetch")
char *host_fetch(const char *url, size_t *out_len);

WEB_IMPORT("host_fetch_post")
char *host_fetch_post(const char *url, const char *body, const char *content_type, size_t *out_len);

WEB_IMPORT("host_sleep_ms")
void host_sleep_ms(int32_t ms);

/* Helper: convert SV to owned C string (caller must free) */
static char *sv_to_cstr(SV *sv) {
    STRLEN len;
    const char *s = SvPV(sv, len);
    char *out = malloc(len + 1);
    if (out) { memcpy(out, s, len); out[len] = '\0'; }
    return out;
}

static void zeroperl_web_set_error(const char *msg) {
    SV *err = get_sv("@", GV_ADD);
    sv_setpv(err, msg);
}

/* XS: ZeroPerl::Web::fetch($url) -> $response */
static XS(xs_fetch) {
    dXSARGS;
    if (items != 1) {
        zeroperl_web_set_error("fetch() takes exactly 1 argument");
        XSRETURN_UNDEF;
    }
    char *url = sv_to_cstr(ST(0));
    size_t out_len = 0;
    char *data = host_fetch(url, &out_len);
    free(url);
    if (!data) {
        zeroperl_web_set_error("host_fetch failed");
        XSRETURN_UNDEF;
    }
    SV *sv = newSVpv(data, out_len);
    free(data);
    ST(0) = sv_2mortal(sv);
    XSRETURN(1);
}

/* XS: ZeroPerl::Web::fetch_json($url) -> $parsed */
static XS(xs_fetch_json) {
    dXSARGS;
    if (items != 1) {
        zeroperl_web_set_error("fetch_json() takes exactly 1 argument");
        XSRETURN_UNDEF;
    }
    char *url = sv_to_cstr(ST(0));
    size_t out_len = 0;
    char *data = host_fetch(url, &out_len);
    free(url);
    if (!data) {
        zeroperl_web_set_error("host_fetch failed");
        XSRETURN_UNDEF;
    }
    SV *sv = newSVpv(data, out_len);
    free(data);
    ST(0) = sv_2mortal(sv);
    XSRETURN(1);
}

/* XS: ZeroPerl::Web::fetch_post($url, $body, $content_type) -> $response */
static XS(xs_fetch_post) {
    dXSARGS;
    if (items != 3) {
        zeroperl_web_set_error("fetch_post() takes exactly 3 arguments");
        XSRETURN_UNDEF;
    }
    char *url = sv_to_cstr(ST(0));
    char *body = sv_to_cstr(ST(1));
    char *ct = sv_to_cstr(ST(2));
    size_t out_len = 0;
    char *data = host_fetch_post(url, body, ct, &out_len);
    free(url); free(body); free(ct);
    if (!data) {
        zeroperl_web_set_error("host_fetch_post failed");
        XSRETURN_UNDEF;
    }
    SV *sv = newSVpv(data, out_len);
    free(data);
    ST(0) = sv_2mortal(sv);
    XSRETURN(1);
}

/* XS: ZeroPerl::Web::sleep($seconds) -> undef */
static XS(xs_sleep) {
    dXSARGS;
    if (items != 1) {
        zeroperl_web_set_error("sleep() takes exactly 1 argument");
        XSRETURN_UNDEF;
    }
    double secs = SvNV(ST(0));
    int32_t ms = (int32_t)(secs * 1000.0);
    if (ms < 0) ms = 0;
    host_sleep_ms(ms);
    XSRETURN_UNDEF;
}

/* Called from main xs_init to register web XS functions */
void zeroperl_web_bootstrap(const char *file) {
    newXS("ZeroPerl::Web::fetch", xs_fetch, file);
    newXS("ZeroPerl::Web::fetch_json", xs_fetch_json, file);
    newXS("ZeroPerl::Web::fetch_post", xs_fetch_post, file);
    newXS("ZeroPerl::Web::sleep", xs_sleep, file);
}
