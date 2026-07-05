#include "async_web_api.h"
#include <stdlib.h>
#include <string.h>

static async_op_t *registry_head = NULL;
static uint32_t next_op_id = 1;

uint32_t async_web_api_register_op(const char *type, const char *arg) {
    async_op_t *op = (async_op_t *)malloc(sizeof(async_op_t));
    if (!op) return 0;
    
    op->id = next_op_id++;
    op->type = type ? strdup(type) : NULL;
    op->arg = arg ? strdup(arg) : NULL;
    op->result = NULL;
    op->status = 0;
    op->completed = false;
    
    // Initialize Asyncify buffer
    op->buf.top = &op->buf.buffer[0];
    op->buf.end = &op->buf.buffer[WASM_ASYNC_STACK_BUFFER_SIZE];
    
    // Add to registry
    op->next = registry_head;
    registry_head = op;
    
    return op->id;
}

async_op_t *async_web_api_find_op(uint32_t op_id) {
    async_op_t *curr = registry_head;
    while (curr) {
        if (curr->id == op_id) {
            return curr;
        }
        curr = curr->next;
    }
    return NULL;
}

void async_web_api_resolve_op(uint32_t op_id, const char *result, int status) {
    async_op_t *op = async_web_api_find_op(op_id);
    if (op) {
        if (op->result) {
            free(op->result);
        }
        op->result = result ? strdup(result) : NULL;
        op->status = status;
        op->completed = true;
    }
}

void *async_web_api_get_op_buf(uint32_t op_id) {
    async_op_t *op = async_web_api_find_op(op_id);
    return op ? &op->buf : NULL;
}

void async_web_api_free_op(uint32_t op_id) {
    async_op_t *prev = NULL;
    async_op_t *curr = registry_head;
    while (curr) {
        if (curr->id == op_id) {
            if (prev) {
                prev->next = curr->next;
            } else {
                registry_head = curr->next;
            }
            if (curr->type) free(curr->type);
            if (curr->arg) free(curr->arg);
            if (curr->result) free(curr->result);
            free(curr);
            return;
        }
        prev = curr;
        curr = curr->next;
    }
}
