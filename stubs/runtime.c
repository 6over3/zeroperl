#include "asyncify.h"
#include "machine.h"
#include "setjmp.h"
#include <stdlib.h>

/* defined in setjmp.c; set by asyncify_start_unwind macro, cleared by asyncify_stop_unwind macro */
extern void *pl_asyncify_unwind_buf;

int asyncjmp_rt_start(int(main)(int argc, char **argv), int argc, char **argv)
{
    int result;
    void *asyncify_buf;

    while (1)
    {
        result = main(argc, argv);

        /* Handle async web API unwind before setjmp buffer checks */
        if ((asyncify_buf = async_web_api_handle_unwind()) != NULL)
        {
            asyncify_start_rewind(asyncify_buf);
            continue;
        }

        /*
         * Only call asyncify_stop_unwind() when this was a C-level unwind
         * initiated by zeroperl's own asyncify_start_unwind() macro.
         * The macro sets pl_asyncify_unwind_buf; asyncify import handling does not.
         *
         * If pl_asyncify_unwind_buf == NULL and main() returned, we are either:
         *   (a) Normal Perl exit: __asyncify_state == 0. Break normally.
         *   (b) Asyncify-import unwind (async web API via call_host_function):
         *       __asyncify_state == 1 (UNWINDING). Do NOT clear it here.
         *       Let it propagate so the JS host detects state == 1, awaits
         *       the Promise, calls asyncify_start_rewind(), and re-invokes
         *       the export to complete the rewind.
         */
        if (pl_asyncify_unwind_buf != NULL)
        {
            /*
             * C-level unwind (setjmp / longjmp / GC scan).
             * NOTE: asyncify_stop_unwind() must be called here (in the loop),
             * not inside the handler functions, or Asyncify inserts another
             * unwind check here and unwinds to the root frame.
             */
            asyncify_stop_unwind();

            if ((asyncify_buf = asyncjmp_handle_jmp_unwind()) != NULL)
            {
                asyncify_start_rewind(asyncify_buf);
                continue;
            }
            if ((asyncify_buf = asyncjmp_handle_scan_unwind()) != NULL)
            {
                asyncify_start_rewind(asyncify_buf);
                continue;
            }
            /* pl_asyncify_unwind_buf was set but no handler claimed it */
            break;
        }

        /* Normal exit or async import unwind */
        break;
    }
    return result;
}
