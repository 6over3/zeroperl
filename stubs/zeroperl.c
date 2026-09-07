const char *name;
            int argc;
            zeroperl_value **argv;
            zeroperl_context_type context;
        } call;
        // Add other operation data if needed
    } data;
} zeroperl_context;

static void zeroperl_call_callback(void *arg) {
    zeroperl_context *ctx = (zeroperl_context *)arg;
    dSP;
    ENTER;
    SAVETMPS;

    switch (ctx->op_type) {
        case ZEROPERL_OP_CALL:
            XPUSHs(sv_2mortal(newSVpv(ctx->data.call.name, 0)));
            for (int i = 0; i < ctx->data.call.argc; i++) {
                XPUSHs(ctx->data.call.argv[i]->sv);
            }
            call_pv("main::" ctx->data.call.name, G_SCALAR | G_EVAL);
            break;
        // Handle other operations if needed
    }

    int count = SP - mark;
    zeroperl_result *result = (zeroperl_result *)malloc(sizeof(zeroperl_result));
    if (!result) {
        FREETMPS;
        LEAVE;
        return;
    }

    result->count = count;

    if (count > 0) {
        result->values =
            (zeroperl_value **)malloc(sizeof(zeroperl_value *) * count);
        if (!result->values) {
            free(result);
            FREETMPS;
            LEAVE;
            return;
        }

        for (int i = count - 1; i >= 0; i--) {
            zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
            if (val) {
                val->sv = SvREFCNT_inc(TOPs);
                result->values[i] = val;
                POPs;
            } else {
                result->values[i] = NULL;
            }
        }
    } else {
        result->values = NULL;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    // Store result pointer in context (caller will retrieve it)
    *((zeroperl_result **)&ctx->result) = result;
}

ZEROPERL_API("zeroperl_call")
zeroperl_result *zeroperl_call(const char *name, zeroperl_context_type context,
                               int argc, zeroperl_value **argv) {
    if (!zero_perl || !zero_perl_can_evaluate || !name) {
        return NULL;
    }

    zeroperl_context ctx = {
        .op_type = ZEROPERL_OP_CALL,
        .result = 0,
        .data.call = {
            .name = name, .argc = argc, .argv = argv, .context = context}};

    int status = asyncjmp_rt_start(zeroperl_call_callback, 0, (char **)&ctx);

    if (status != 0) {
        return NULL;
    }

    return *((zeroperl_result **)&ctx.result);
}

ZEROPERL_API("zeroperl_result_get")
zeroperl_value *zeroperl_result_get(zeroperl_result *result, int index) {
    if (!result || index < 0 || index >= result->count) {
        return NULL;
    }

    return result->values[index];
}

ZEROPERL_API("zeroperl_result_free")
void zeroperl_result_free(zeroperl_result *result) {
    if (!result) {
        return;
    }

    if (result->values) {
        for (int i = 0; i < result->count; i++) {
            if (result->values[i]) {
                zeroperl_value_free(result->values[i]);
            }
        }
        free(result->values);
    }

    free(result);
}

static void xs_init(pTHX) {
    static const char file[] = __FILE__;
    dXSUB_SYS;
    PERL_UNUSED_CONTEXT;

    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
    newXS("File::Glob::bootstrap", boot_File__Glob, file);
    newXS("Sys::Hostname::bootstrap", boot_Sys__Hostname, file);
    newXS("PerlIO::via::bootstrap", boot_PerlIO__via, file);
    newXS("PerlIO::mmap::bootstrap", boot_PerlIO__mmap, file);
    newXS("PerlIO::encoding::bootstrap", boot_PerlIO__encoding, file);
    newXS("attributes::bootstrap", boot_attributes, file);
    newXS("Unicode::Normalize::bootstrap", boot_Unicode__Normalize, file);
    newXS("Unicode::Collate::bootstrap", boot_Unicode__Collate, file);
    newXS("re::bootstrap", boot_re, file);
    newXS("Digest::MD5::bootstrap", boot_Digest__MD5, file);
    newXS("Digest::SHA::bootstrap", boot_Digest__SHA, file);
    newXS("Math::BigInt::FastCalc::bootstrap", boot_Math__BigInt__FastCalc, file);
    newXS("Data::Dumper::bootstrap", boot_Data__Dumper, file);
    newXS("I18N::Langinfo::bootstrap", boot_I18N__Langinfo, file);
    newXS("Time::Piece::bootstrap", boot_Time__Piece, file);
    newXS("IO::bootstrap", boot_IO, file);
    newXS("Hash::Util::FieldHash::bootstrap", boot_Hash__Util__FieldHash, file);
    newXS("Hash::Util::bootstrap", boot_Hash__Util, file);
    newXS("Filter::Util::Call::bootstrap", boot_Filter__Util__Call, file);
    newXS("Encode::Unicode::bootstrap", boot_Encode__Unicode, file);
    newXS("Encode::bootstrap", boot_Encode, file);
    newXS("Encode::JP::bootstrap", boot_Encode__JP, file);
    newXS("Encode::KR::bootstrap", boot_Encode__KR, file);
    newXS("Encode::EBCDIC::bootstrap", boot_Encode__EBCDIC, file);
    newXS("Encode::CN::bootstrap", boot_Encode__CN, file);
    newXS("Encode::Symbol::bootstrap", boot_Encode__Symbol, file);
    newXS("Encode::Byte::bootstrap", boot_Encode__Byte, file);
    newXS("Encode::TW::bootstrap", boot_Encode__TW, file);
    newXS("Compress::Raw::Zlib::bootstrap", boot_Compress__Raw__Zlib, file);
    newXS("Compress::Raw::Bzip2::bootstrap", boot_Compress__Raw__Bzip2, file);
    newXS("MIME::Base64::bootstrap", boot_MIME__Base64, file);
    newXS("Cwd::bootstrap", boot_Cwd, file);
    newXS("List::Util::bootstrap", boot_List__Util, file);
    newXS("Fcntl::bootstrap", boot_Fcntl, file);
    newXS("Opcode::bootstrap", boot_Opcode, file);
    newXS("Time::HiRes::bootstrap", boot_Time__HiRes, file);
}