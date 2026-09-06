/* Linked against native libperl and the verbatim production hash-delete body. */
#include <stdbool.h>
#include <stdio.h>
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
/* Perl release headers may define NDEBUG; checks must remain active. */
#undef NDEBUG
#include <assert.h>
static PerlInterpreter *my_perl;
typedef struct { HV *hv; } zeroperl_hash;
#define ZEROPERL_API(name)
#include "hash-delete-function.inc"
static int destroyed;
static XS(destroy_probe) {
    dXSARGS;
    destroyed++;
    XSRETURN_EMPTY;
}

static void xs_init(pTHX) {
    newXS("DeleteProbe::DESTROY", destroy_probe, __FILE__);
}

int main(int argc, char **argv, char **env) {
    PERL_SYS_INIT3(&argc, &argv, &env);
    my_perl = perl_alloc();
    assert(my_perl);
    perl_construct(my_perl);
    char *args[] = {"zeroperl-test", "-e", "0", NULL};
    assert(perl_parse(my_perl, xs_init, 3, args, NULL) == 0);
    zeroperl_hash hash = {newHV()};
    assert(!zeroperl_hash_delete(NULL, "key"));
    assert(!zeroperl_hash_delete(&hash, NULL));
    assert(!zeroperl_hash_delete(&hash, "missing"));
    for (int i = 0; i < 100; i++) {
        ENTER;
        SAVETMPS;
        SV *retained = newSViv(42);
        assert(hv_store(hash.hv, "key", 3, SvREFCNT_inc(retained), 0));
        assert(zeroperl_hash_delete(&hash, "key"));
        assert(!hv_exists(hash.hv, "key", 3));
        /* Only our retained reference remains with G_DISCARD. */
        assert(SvREFCNT(retained) == 1);
        FREETMPS;
        LEAVE;
        assert(SvREFCNT(retained) == 1);
        assert(SvIV(retained) == 42);
        SvREFCNT_dec(retained);

        ENTER;
        SAVETMPS;
        SV *object = newRV_noinc((SV *)newHV());
        sv_bless(object, gv_stashpv("DeleteProbe", GV_ADD));
        assert(hv_store(hash.hv, "object", 6, object, 0));
        assert(zeroperl_hash_delete(&hash, "object"));
        FREETMPS;
        LEAVE;
        assert(destroyed == i + 1);
        assert(!zeroperl_hash_delete(&hash, "object"));

        assert(hv_store(hash.hv, "undef", 5, newSV(0), 0));
        assert(zeroperl_hash_delete(&hash, "undef"));
        assert(!zeroperl_hash_delete(&hash, "undef"));
    }
    SvREFCNT_dec((SV *)hash.hv);
    perl_destruct(my_perl);
    perl_free(my_perl);
    PERL_SYS_TERM();
    puts("100 hash deletion cycles passed (retained values, DESTROY, undef, missing keys)");
    return 0;
}
