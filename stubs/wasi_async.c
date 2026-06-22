/*
 * Custom async WASI fd operations - resolves conflict between
 * Google Asyncify (for WASI I/O) and WebAssembly Perl5 asyncjmp setjmp.
 * 
 * Problem:
 * - Perl5 asyncjmp uses pl_asyncify_unwind_buf to track setjmp context.
 * - WASI SDK's fd_read internally calls raw asyncify_start_unwind() which
 *   does NOT set pl_asyncify_unwind_buf (it doesn't include asyncify.h).
 * - When both are active simultaneously, asyncjmp_rt_start's loop sees
 *   pl_asyncify_unwind_buf == NULL and breaks, but the asyncify rewind
 *   happens in the wrong place → crash or infinite loop.
 * 
 * Solution:
 * - Provide custom __wasi_fd_read that uses async_web_api_unwind() instead
 *   of raw asyncify_start_unwind().
 * - Uses SEPARATE asyncify buffer (_async_web_api_buf) for WASI I/O,
 *   completely isolated from asyncjmp's setjmp buffer.
 * - runtime.c's async_web_api_handle_unwind() catches the rewind.
 * 
 * Build: compiled as wasi_async.o, linked BEFORE WASI SDK libraries so
 * our __wasi_fd_read overrides any conflicting symbol from the SDK.
 */

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <wasi/api.h>
#include "machine.h"
#include "asyncify.h"

/*
 * WASI import declarations - these reference the actual host implementations.
 * We use our own wrappers so we control when async_web_api_unwind is called.
 */
__attribute__((import_module("wasi_snapshot_preview1"), import_name("fd_read")))
__wasi_errno_t __wasi_fd_read_impl(
    __wasi_fd_t fd, const __wasi_iovec_t *iovs,
    size_t iovs_len, __wasi_size_t *nread);

__attribute__((import_module("wasi_snapshot_preview1"), import_name("fd_write")))
__wasi_errno_t __wasi_fd_write_impl(
    __wasi_fd_t fd, const __wasi_ciovec_t *iovs,
    size_t iovs_len, __wasi_size_t *nwritten);

__attribute__((import_module("wasi_snapshot_preview1"), import_name("fd_pread")))
__wasi_errno_t __wasi_fd_pread_impl(
    __wasi_fd_t fd, const __wasi_iovec_t *iovs,
    size_t iovs_len, __wasi_filesize_t offset,
    __wasi_size_t *nread);

/*
 * Async read context - persists in WASM linear memory across unwind/rewind.
 */
#define MAX_SAVED_IOVS 16

typedef struct {
    uint8_t *buf;
    size_t buf_len;
} saved_iov_t;

static saved_iov_t _saved_iovs[MAX_SAVED_IOVS];
static size_t _saved_iovs_len = 0;

typedef struct {
    __wasi_size_t     nread;    /* result */
    __wasi_errno_t    err;      /* result errno */
    bool              in_progress;
} async_read_ctx_t;

static async_read_ctx_t _ars = { .in_progress = false };

/*
 * __wasi_fd_read - custom async implementation using isolated async web API.
 * 
 * Flow:
 * 1. First call: save buffer pointers to linear memory, call async_web_api_unwind().
 *    async_web_api_unwind() does: init _async_web_api_buf, asyncify_start_unwind.
 *    Returns to runtime loop.
 * 2. runtime loop: async_web_api_handle_unwind() returns _async_web_api_buf,
 *    calls asyncify_start_rewind(), rewind resumes after async_web_api_unwind().
 * 3. Resume after rewind: detects rewind state using asyncify_get_state() == 2.
 *    Calls async_web_api_stop() to transition asyncify state back to normal,
 *    then calls __wasi_fd_read_impl (blocking host call) using saved buffers,
 *    and returns the result.
 */
__attribute__((noinline)) 
__wasi_errno_t __wasi_fd_read(
    __wasi_fd_t              fd,
    const __wasi_iovec_t    *iovs,
    size_t                   iovs_len,
    __wasi_size_t           *nread)
{
    /* First call: initiate async read */
    if (iovs_len > 0 && iovs) {
        _saved_iovs_len = iovs_len < MAX_SAVED_IOVS ? iovs_len : MAX_SAVED_IOVS;
        for (size_t i = 0; i < _saved_iovs_len; i++) {
            _saved_iovs[i].buf = (uint8_t*)(uintptr_t)iovs[i].buf;
            _saved_iovs[i].buf_len = iovs[i].buf_len;
        }
        _ars.nread = 0;
        _ars.err = __WASI_ERRNO_SUCCESS;
        _ars.in_progress = true;
    } else {
        return __WASI_ERRNO_INVAL;
    }
    
    async_web_api_unwind();
    
    /* During rewind, execution resumes here! */
    if (asyncify_get_state() == 2) { // 2 == ASYNCIFY_STATE_REWINDING
        /* Stop async web API unwind and restore context */
        async_web_api_stop();
        _ars.in_progress = false;
        
        if (_saved_iovs_len > 0) {
            /* Construct temporary iovec array using saved pointers */
            __wasi_iovec_t local_iovs[MAX_SAVED_IOVS];
            for (size_t i = 0; i < _saved_iovs_len; i++) {
                local_iovs[i].buf = _saved_iovs[i].buf;
                local_iovs[i].buf_len = _saved_iovs[i].buf_len;
            }
            _ars.err = __wasi_fd_read_impl(fd, local_iovs, _saved_iovs_len, &_ars.nread);
        } else {
            _ars.nread = 0;
            _ars.err = __WASI_ERRNO_SUCCESS;
        }
        
        _saved_iovs_len = 0; // reset
    }
    
    if (nread) *nread = _ars.nread;
    return _ars.err;
}

/*
 * __wasi_fd_write - forward to original import (no async needed for writes).
 * The WASI SDK's fd_write is handled by wasm-opt asyncify instrumentation.
 */
__attribute__((noinline))
__wasi_errno_t __wasi_fd_write(
    __wasi_fd_t              fd,
    const __wasi_ciovec_t   *iovs,
    size_t                   iovs_len,
    __wasi_size_t           *nwritten)
{
    return __wasi_fd_write_impl(fd, iovs, iovs_len, nwritten);
}

/*
 * __wasi_fd_pread - forward to original import (no async needed).
 */
__attribute__((noinline))
__wasi_errno_t __wasi_fd_pread(
    __wasi_fd_t              fd,
    const __wasi_iovec_t    *iovs,
    size_t                   iovs_len,
    __wasi_filesize_t        offset,
    __wasi_size_t           *nread)
{
    return __wasi_fd_pread_impl(fd, iovs, iovs_len, offset, nread);
}
