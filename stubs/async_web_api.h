#ifndef ASYNC_WEB_API_H
#define ASYNC_WEB_API_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef ZEROPERL_API
#define ZEROPERL_API(name) __attribute__((visibility("default")))
#endif

#ifndef ZEROPERL_IMPORT
#define ZEROPERL_IMPORT(name) __attribute__((import_module("env"), import_name(name)))
#endif

#ifndef WASM_ASYNC_STACK_BUFFER_SIZE
#define WASM_ASYNC_STACK_BUFFER_SIZE 32768
#endif

typedef struct __async_web_api_buf {
    void *top;
    void *end;
    char buffer[WASM_ASYNC_STACK_BUFFER_SIZE];
} async_web_api_buf_t;

typedef struct async_op {
    uint32_t id;
    char *type;
    char *arg;
    char *result;
    int status; // 0 = pending, 1 = resolved, 2 = rejected
    bool completed;
    async_web_api_buf_t buf;
    struct async_op *next;
} async_op_t;

// C API
ZEROPERL_API("async_web_api_register_op")
uint32_t async_web_api_register_op(const char *type, const char *arg);

ZEROPERL_API("async_web_api_resolve_op")
void async_web_api_resolve_op(uint32_t op_id, const char *result, int status);

ZEROPERL_API("async_web_api_get_op_buf")
void *async_web_api_get_op_buf(uint32_t op_id);

ZEROPERL_API("async_web_api_find_op")
async_op_t *async_web_api_find_op(uint32_t op_id);

ZEROPERL_API("async_web_api_free_op")
void async_web_api_free_op(uint32_t op_id);

// Host Call Import
ZEROPERL_IMPORT("async_web_api_host_call")
void async_web_api_host_call(uint32_t op_id, const char *type, const char *arg);

#endif // ASYNC_WEB_API_H
