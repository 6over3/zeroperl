#include "asyncify.h"
#include "machine.h"
#include "setjmp.h"
#include <stdlib.h>

int asyncjmp_rt_start(int(main)(int argc, char **argv), int argc, char **argv)
{
    int result;
    void *asyncify_buf;

    while (1)
    {
        result = main(argc, argv);

        extern void *pl_asyncify_unwind_buf;
        if (pl_asyncify_unwind_buf != NULL)
        {
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
            break;
        }

        break;
    }
    return result;
}
