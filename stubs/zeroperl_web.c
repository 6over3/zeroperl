#include "zeroperl.h"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

// Define host function IDs for Web APIs
#define HOST_FUNC_FETCH 1001
#define HOST_FUNC_SLEEP 1002

// External declaration for the host call function
extern zeroperl_value *host_call_function(int32_t func_id, int32_t argc, zeroperl_value **argv);

// Helper to create a zeroperl_value from SV
static zeroperl_value *create_zeroperl_value(pTHX_ SV *sv) {
    zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
    if (val) {
        val->sv = sv;
        SvREFCNT_inc(sv);
    }
    return val;
}

// Helper to process result from host call
static void process_host_result(pTHX_ zeroperl_value *result) {
    if (result && result->sv) {
        ST(0) = sv_2mortal(SvREFCNT_inc(result->sv));
        zeroperl_value_free(result);
        XSRETURN(1);
    } else {
        if (result) zeroperl_value_free(result);
        XSRETURN_UNDEF;
    }
}

XS(XS_ZeroPerl__Web_fetch) {
    dXSARGS;
    if (items < 1) {
        croak("Usage: ZeroPerl::Web::fetch(url, [options])");
    }

    // Prepare arguments for host call
    zeroperl_value **argv = (zeroperl_value **)malloc(sizeof(zeroperl_value *) * items);
    for (int i = 0; i < items; i++) {
        argv[i] = create_zeroperl_value(aTHX_ ST(i));
    }

    // Make the host call
    // This will trigger asyncify unwind if needed
    zeroperl_value *result = host_call_function(HOST_FUNC_FETCH, items, argv);

    // Cleanup arguments
    for (int i = 0; i < items; i++) {
        zeroperl_value_free(argv[i]);
    }
    free(argv);

    process_host_result(aTHX_ result);
}

XS(XS_ZeroPerl__Web_sleep) {
    dXSARGS;
    if (items != 1) {
        croak("Usage: ZeroPerl::Web::sleep(ms)");
    }

    zeroperl_value **argv = (zeroperl_value **)malloc(sizeof(zeroperl_value *) * 1);
    argv[0] = create_zeroperl_value(aTHX_ ST(0));

    zeroperl_value *result = host_call_function(HOST_FUNC_SLEEP, 1, argv);

    zeroperl_value_free(argv[0]);
    free(argv);

    process_host_result(aTHX_ result);
}

// Bootstrap function
XS(boot_ZeroPerl__Web) {
    dXSARGS;
    char* file = __FILE__;

    newXS("ZeroPerl::Web::fetch", XS_ZeroPerl__Web_fetch, file);
    newXS("ZeroPerl::Web::sleep", XS_ZeroPerl__Web_sleep, file);

    XSRETURN_YES;
}
