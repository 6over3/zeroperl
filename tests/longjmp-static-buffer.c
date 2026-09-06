/* Exercise the production setjmp state machine with native Asyncify hooks.
 * AddressSanitizer detects the original free of static scratch storage. */
#include <assert.h>
#include <stdio.h>
#include "../stubs/setjmp.c"

#undef asyncify_start_unwind
#undef asyncify_stop_unwind
#undef asyncify_stop_rewind
void asyncify_start_unwind(void *buf) { assert(buf != NULL); }
void asyncify_stop_unwind(void) { pl_asyncify_unwind_buf = NULL; }
void asyncify_stop_rewind(void) { pl_asyncify_unwind_buf = NULL; }
void *asyncjmp_get_stack_pointer(void) { return NULL; }
void asyncjmp_set_stack_pointer(void *sp) { (void)sp; }

int main(void) {
    asyncjmp_jmp_buf env = {0};
    assert(_asyncjmp_setjmp_internal(&env) == -1);
    assert(asyncjmp_handle_jmp_unwind() == &env.setjmp_buf);
    assert(_asyncjmp_setjmp_internal(&env) == 0);
    for (int payload = 1; payload <= 100; payload++) {
        _asyncjmp_longjmp(&env, payload);
        assert(env.longjmp_buf_ptr != NULL);
        assert(asyncjmp_handle_jmp_unwind() == &env.setjmp_buf);
        assert(_asyncjmp_setjmp_internal(&env) == payload);
        assert(asyncjmp_handle_jmp_unwind() == NULL);
    }
    puts("100 longjmp recovery cycles passed");
    return 0;
}
