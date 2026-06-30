/**
 * zeroperl_web.c — Async Web API stubs for zeroperl (Perl in WASM)
 *
 * Provides fetch() and sleep() implementations that bridge Perl
 * code running in WebAssembly to host (JavaScript) async APIs.
 *
 * fetch($url) — HTTP GET request via WASI host import
 * sleep($seconds) — non-blocking sleep via asyncify yield
 *
 * Architecture:
 *   Perl code → XSUB → zeroperl_web_* → WASM import → JS host
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "asyncify.h"

/* ===================================================================
 * WASM imports — provided by the JavaScript host environment
 * =================================================================== */

/* 
 * Host function: perform an HTTP GET request.
 * Returns a pointer to a null-terminated response string in WASM linear memory.
 * The host writes the response into a buffer allocated by zeroperl.
 * Returns NULL on error.
 */
__attribute__((import_module("env"), import_name("host_fetch")))
extern void *host_fetch(const char *url, int *out_len);

/*
 * Host function: perform an HTTP POST request.
 * Returns a pointer to a null-terminated response string.
 */
__attribute__((import_module("env"), import_name("host_fetch_post")))
extern void *host_fetch_post(const char *url, const char *body, const char *content_type, int *out_len);

/*
 * Host function: async sleep — returns when done.
 */
__attribute__((import_module("env"), import_name("host_sleep_ms")))
extern void host_sleep_ms(int milliseconds);

/* ===================================================================
 * Error buffer
 * =================================================================== */

static char web_error_buf[512] = {0};

/* ===================================================================
 * Helper: read null-terminated string from WASM memory
 * =================================================================== */

static size_t web_strlen(const char *s) {
    size_t len = 0;
    if (!s) return 0;
    while (s[len] != '\0') len++;
    return len;
}

/* ===================================================================
 * zeroperl_web_fetch — XSUB for Perl's fetch() function
 *
 * Usage from Perl:
 *   my $response = fetch("https://api.example.com/data");
 *
 * Returns the response body as a string, or undef on error.
 * =================================================================== */

XS(XS_ZeroPerl_Web_fetch)
{
    dXSARGS;
    
    if (items < 1) {
        croak("Usage: fetch($url)");
    }
    
    const char *url = SvPV_nolen(ST(0));
    if (!url || *url == '\0') {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    int out_len = 0;
    void *response = host_fetch(url, &out_len);
    
    if (!response || out_len <= 0) {
        safesysfree(response);
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    ST(0) = sv_2mortal(newSVpvn((const char *)response, (STRLEN)out_len));
    safesysfree(response);
    XSRETURN(1);
}

/* ===================================================================
 * zeroperl_web_fetch_json — fetch with JSON decoding
 *
 * Usage from Perl:
 *   my $data = fetch_json("https://api.example.com/data");
 * =================================================================== */

XS(XS_ZeroPerl_Web_fetch_json)
{
    dXSARGS;
    
    if (items < 1) {
        croak("Usage: fetch_json($url)");
    }
    
    const char *url = SvPV_nolen(ST(0));
    if (!url || *url == '\0') {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    int out_len = 0;
    void *response = host_fetch(url, &out_len);
    
    if (!response || out_len <= 0) {
        safesysfree(response);
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    /* Return raw response — JSON parsing done in Perl */
    ST(0) = sv_2mortal(newSVpvn((const char *)response, (STRLEN)out_len));
    safesysfree(response);
    XSRETURN(1);
}

/* ===================================================================
 * zeroperl_web_fetch_post — HTTP POST
 *
 * Usage from Perl:
 *   my $response = fetch_post($url, $body, $content_type);
 * =================================================================== */

XS(XS_ZeroPerl_Web_fetch_post)
{
    dXSARGS;
    
    if (items < 2) {
        croak("Usage: fetch_post($url, $body, [$content_type])");
    }
    
    const char *url = SvPV_nolen(ST(0));
    const char *body = SvPV_nolen(ST(1));
    const char *content_type = "application/json";
    
    if (items >= 3) {
        content_type = SvPV_nolen(ST(2));
    }
    
    if (!url || !body) {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    int out_len = 0;
    void *response = host_fetch_post(url, body, content_type, &out_len);
    
    if (!response || out_len <= 0) {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }
    
    ST(0) = sv_2mortal(newSVpvn((const char *)response, (STRLEN)out_len));
    safesysfree(response);
    XSRETURN(1);
}

/* ===================================================================
 * zeroperl_web_sleep — non-blocking sleep
 *
 * Usage from Perl:
 *   sleep(1.5);  # sleep 1.5 seconds
 *
 * Uses asyncify to yield back to the runtime, allowing other
 * WASM callers to make progress during the sleep.
 * =================================================================== */

XS(XS_ZeroPerl_Web_sleep)
{
    dXSARGS;
    
    if (items < 1) {
        croak("Usage: sleep($seconds)");
    }
    
    double seconds = SvNV(ST(0));
    if (seconds <= 0) {
        XSRETURN_EMPTY;
    }
    
    int milliseconds = (int)(seconds * 1000.0);
    if (milliseconds < 1) milliseconds = 1;
    
    /* Yield via asyncify — host will call back after timeout */
    host_sleep_ms(milliseconds);
    
    XSRETURN_EMPTY;
}

/* ===================================================================
 * Bootstrap — register XSUBs with Perl
 * =================================================================== */

MODULE = ZeroPerl::Web  PACKAGE = ZeroPerl::Web

PROTOTYPES: ENABLE

void
fetch(url)
    const char *url
    CODE:
        /* Handled by XS above */
    OUTPUT:
        RETVAL

void
fetch_json(url)
    const char *url
    CODE:
        /* Handled by XS above */
    OUTPUT:
        RETVAL

void
fetch_post(url, body, ...)
    const char *url
    const char *body
    CODE:
        /* Handled by XS above */
    OUTPUT:
        RETVAL

void
sleep(seconds)
    double seconds
    CODE:
        /* Handled by XS above */
    OUTPUT:
        RETVAL

/* ===================================================================
 * End of zeroperl_web.c
 * =================================================================== */
