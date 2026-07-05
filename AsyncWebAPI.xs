#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "async_web_api.h"
#include "asyncify.h"

MODULE = AsyncWebAPI		PACKAGE = AsyncWebAPI		

SV *
fetch(url)
    const char *url
    PREINIT:
        uint32_t op_id = 0;
        async_op_t *op = NULL;
        int state = 0;
    CODE:
        state = asyncify_get_state();
        if (state == 0) { /* Normal execution */
            op_id = async_web_api_register_op("fetch", url);
            if (op_id == 0) {
                XSRETURN_UNDEF;
            }
            
            /* Call host to start the async fetch operation */
            async_web_api_host_call(op_id, "fetch", url);
            
            /* Prepare Asyncify stack unwinding */
            extern void *pl_asyncify_unwind_buf;
            pl_asyncify_unwind_buf = async_web_api_get_op_buf(op_id);
            asyncify_start_unwind(pl_asyncify_unwind_buf);
            
            XSRETURN_UNDEF;
        } else if (state == 2) { /* Rewinding execution */
            asyncify_stop_rewind();
            extern void *pl_asyncify_unwind_buf;
            pl_asyncify_unwind_buf = NULL;
            
            /* op_id is restored by Asyncify from the stack frame */
            op = async_web_api_find_op(op_id);
            if (op && op->completed) {
                if (op->status == 1) { /* resolved */
                    RETVAL = newSVpv(op->result ? op->result : "", 0);
                } else { /* rejected / error */
                    async_web_api_free_op(op_id);
                    croak("Async fetch operation failed");
                }
                async_web_api_free_op(op_id);
            } else {
                RETVAL = newSVsv(&PL_sv_undef, 0);
            }
        } else {
            RETVAL = newSVsv(&PL_sv_undef, 0);
        }
    OUTPUT:
        RETVAL

SV *
sleep(seconds)
    int seconds
    PREINIT:
        uint32_t op_id = 0;
        async_op_t *op = NULL;
        int state = 0;
        char sec_str[32];
    CODE:
        state = asyncify_get_state();
        if (state == 0) { /* Normal execution */
            snprintf(sec_str, sizeof(sec_str), "%d", seconds);
            op_id = async_web_api_register_op("sleep", sec_str);
            if (op_id == 0) {
                XSRETURN_UNDEF;
            }
            
            /* Call host to start the async sleep/timer operation */
            async_web_api_host_call(op_id, "sleep", sec_str);
            
            /* Prepare Asyncify stack unwinding */
            extern void *pl_asyncify_unwind_buf;
            pl_asyncify_unwind_buf = async_web_api_get_op_buf(op_id);
            asyncify_start_unwind(pl_asyncify_unwind_buf);
            
            XSRETURN_UNDEF;
        } else if (state == 2) { /* Rewinding execution */
            asyncify_stop_rewind();
            extern void *pl_asyncify_unwind_buf;
            pl_asyncify_unwind_buf = NULL;
            
            op = async_web_api_find_op(op_id);
            if (op && op->completed) {
                RETVAL = newSViv(op->status == 1 ? 1 : 0);
                async_web_api_free_op(op_id);
            } else {
                RETVAL = newSVsv(&PL_sv_undef, 0);
            }
        } else {
            RETVAL = newSVsv(&PL_sv_undef, 0);
        }
    OUTPUT:
        RETVAL
