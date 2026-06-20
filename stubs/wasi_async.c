/*
 * Custom async WASI fd operations - resolves conflict between
 * Google Asyncify (for WASI I/O) and Ruby/wasm asyncjmp setjmp.
 * 
 * Problem:
 * - Ruby/wasm asyncjmp uses pl_asyncify_unwind_buf to track setjmp context.
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
 * This is the key: we store state in linear memory (not on C stack),
 * so it survives the asyncify unwind/rewind cycle.
 */
typedef struct {
    __wasi_fd_t       fd;
    uint8_t          *buf;      /* pointer into caller's buffer */
    size_t            buf_len;  /* length of caller's buffer */
    __wasi_size_t     nread;    /* result */
    __wasi_errno_t    err;      /* result errno */
    bool              in_progress;
} async_read_ctx_t;

static async_read_ctx_t _ars = { .in_progress = false };

/*
 * __wasi_fd_read - custom async implementation using isolated async web API.
 * 
 * Flow:
 * 1. First call: save state to linear memory, call async_web_api_unwind().
 *    async_web_api_unwind() does: init _async_web_api_buf, asyncify_start_unwind.
 *    Returns to runtime loop.
 * 2. runtime loop: async_web_api_handle_unwind() returns _async_web_api_buf,
 *    calls asyncify_start_rewind(), rewind resumes at step 3.
 * 3. Resume after rewind: call __wasi_fd_read_impl (blocking host call),
 *    cache result in _ars (linear memory), call async_web_api_stop(),
 *    return to caller (which is the rewind target in __wrap_read).
 * 4. Subsequent calls return cached result.
 */
__attribute__((noinline)) 
__wasi_errno_t __wasi_fd_read(
    __wasi_fd_t              fd,
    const __wasi_iovec_t    *iovs,
    size_t                   iovs_len,
    __wasi_size_t           *nread)
{
    /* Check if we completed a previous async read - return cached result */
    if (_ars.in_progress == false && _ars.buf != NULL) {
        /* Completed read from a previous async call */
        if (nread) *nread = _ars.nread;
        _ars.buf = NULL;
        return _ars.err;
    }
    
    /* Check if we're resuming after an async unwind (rewind landed here) */
    if (_ars.in_progress) {
        /* Rewind happened: do the actual blocking read now */
        _ars.in_progress = false;
        
        if (iovs_len > 0 && iovs && _ars.buf != NULL) {
            /* Read into the saved buffer pointer (still valid since it's linear memory) */
            __wasi_iovec_t local_iov = { .buf = _ars.buf, .buf_len = _ars.buf_len };
            _ars.err = __wasi_fd_read_impl(fd, &local_iov, 1, &_ars.nread);
        } else {
            _ars.nread = 0;
            _ars.err = __WASI_ERRNO_SUCCESS;
        }
        
        if (nread) *nread = _ars.nread;
        
        /* Stop async web API unwind and return to caller */
        async_web_api_stop();
        return _ars.err;
    }
    
    /* First call: initiate async read */
    if (iovs_len > 0 && iovs) {
        _ars.fd = fd;
        _ars.buf = (uint8_t*)(uintptr_t)iovs[0].buf;
        _ars.buf_len = iovs[0].buf_len;
        _ars.nread = 0;
        _ars.err = __WASI_ERRNO_SUCCESS;
        _ars.in_progress = true;  /* Mark as "waiting for rewind" */
    } else {
        return __WASI_ERRNO_INVAL;
    }
    
    /* 
     * Key line: call async_web_api_unwind() instead of raw asyncify_start_unwind.
     * This uses _async_web_api_buf (separate from asyncjmp's setjmp buffer).
     * runtime.c's async_web_api_handle_unwind() will catch the rewind.
     */
    async_web_api_unwind();
    
    /* After rewind, we resume here. The in_progress flag tells us
     * this is the rewind path, so we go to the "if (in_progress)" block above. */
    _ars.in_progress = false;
    
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
