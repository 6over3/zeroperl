#!/bin/sh
set -e

# Cross-compile Perl for wasm32-wasi.
#
# Pipeline position: runs after build-native-perl.sh and build-wasi-libs.sh.
# Downloads the Perl source, applies WASI-specific hints and patches,
# configures for cross-compilation, builds libperl.a and the perl binary,
# and installs into /zeroperl.
#
# Supports Perl 5.16.3 through 5.42.2 with version-specific workarounds
# for older releases (OLD_PERL path for ≤5.18).

PERL_VERSION="${PERL_VERSION:-5.42.2}"
URLPERL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"
WASI_SDK_PATH="${WASI_SDK_PATH:-/opt/wasi-sdk}"
WASM_DIR="${WASM_DIR:-/build/wasm}"
NATIVE_DIR="${NATIVE_DIR:-/build/native}"
REPO_DIR="${REPO_DIR:-/build/repo}"
NPROC="${NPROC:-$(nproc)}"
ZEROPERL_SHRINK="${ZEROPERL_SHRINK:-off}"

export PATH="$REPO_DIR/wasi-bin:$PATH"

PERL_MAJOR=$(echo "$PERL_VERSION" | cut -d. -f1)
PERL_MINOR=$(echo "$PERL_VERSION" | cut -d. -f2)

if [ "$PERL_MAJOR" -lt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -lt 16 ]; }; then
    echo "error: Perl $PERL_VERSION is not supported. Minimum supported version is 5.16.3." >&2
    exit 1
fi

# Perl 5.20.x has a memory corruption bug when compiled to wasm32-wasi that
# crashes during compilation of modules like Carp and Encode. The bug
# reproduces across WASM runtimes (wazero, V8). Use 5.18.4 or 5.22.x instead.
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -eq 20 ]; then
    echo "error: Perl 5.20.x is not supported in zeroperl due to a WASM code-generation" >&2
    echo "       bug that corrupts memory during module loading." >&2
    exit 1
fi

OLD_PERL=0
if [ "$PERL_MAJOR" -lt 5 ] || { [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -le 18 ]; }; then
    OLD_PERL=1
fi

mkdir -p "$WASM_DIR"
curl -fsSL "$URLPERL" | tar -xzf - --strip-components=1 --directory="$WASM_DIR"

WASI_VERSION=$(cat "$WASI_SDK_PATH/VERSION" 2>/dev/null | tr -d '\n' || echo "unknown")

# Generate hints with path substitutions
sed -e "s|__STUBS_DIR__|$REPO_DIR/stubs|g" \
    -e "s|__WASI_SDK_PATH__|$WASI_SDK_PATH|g" \
    -e "s|__NATIVE_DIR__|$NATIVE_DIR|g" \
    -e "s|__WASI_SDK_VERSION__|wasi-sdk-$WASI_VERSION|g" \
    "$REPO_DIR/pipeline/hints-wasi.sh" > "$WASM_DIR/hints/wasi.sh"

# 5.38.x: PL_cur_locale_obj referenced under wrong #ifdef guard in perl.c
# and locale.c — prevent USE_POSIX_2008_LOCALE from being defined.
# Also remove 're' from static_ext: regcomp.c symbols duplicated in re.a
# for this version (get_ANYOFHbbm_contents etc.).
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -eq 38 ]; then
    cat >> "$WASM_DIR/hints/wasi.sh" << 'HINTS_538'
d_newlocale='undef'
d_uselocale='undef'
d_duplocale='undef'
d_freelocale='undef'
d_querylocale='undef'
static_ext='mro Time/HiRes File/Glob Sys/Hostname PerlIO/via PerlIO/mmap PerlIO/encoding attributes Unicode/Collate Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/Piece IO Hash/Util/FieldHash Hash/Util Filter/Util/Call Encode/Unicode Encode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode'
HINTS_538
fi

# Append version-specific hint overrides for 5.20 and earlier
if [ "$OLD_PERL" = 1 ]; then
    # Add -Wno-return-mismatch to ccflags/cppflags by appending to the
    # hints file.  The variables are expanded when Configure sources the
    # hints, so the original flags (set earlier in the file) are preserved.
    cat >> "$WASM_DIR/hints/wasi.sh" << 'HINTS_OLD_FLAGS'
ccflags="$ccflags -Wno-return-mismatch"
cppflags="$cppflags -Wno-return-mismatch"
HINTS_OLD_FLAGS

    # Extension list: all OLD_PERL versions use the same set
    # (POSIX, Socket, etc. need sys/wait.h and other WASI-missing headers)
    WASI_STATIC_EXT="mro Time/HiRes File/Glob Sys/Hostname PerlIO/via PerlIO/encoding attributes Unicode/Normalize re Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo IO Hash/Util Filter/Util/Call Encode Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode Unicode/Collate Time/Piece Hash/Util/FieldHash PerlIO/mmap"
    WASI_NOEXT="POSIX Socket Devel/Peek Sys/Syslog B Storable threads threads/shared IPC/SysV SDBM_File File/DosGlob Errno"

    cat >> "$WASM_DIR/hints/wasi.sh" << HINTS
# 5.18 and earlier overrides (built for $PERL_VERSION)
d_setlocale='define'
i_systime='undef'
i_systimek='undef'
i_systimes='define'
d_setgid='undef'
d_setuid='undef'
d_setegid='undef'
d_seteuid='undef'
d_setregid='undef'
d_setresgid='undef'
d_setresuid='undef'
d_setreuid='undef'
noextensions='$WASI_NOEXT'
static_ext='$WASI_STATIC_EXT'
HINTS
fi

# Perl 5.28.x has locale-related compile bugs when USE_LOCALE is undefined
# (lc_numeric_set used outside #ifdef, _CHECK_AND_WARN_PROBLEMATIC_LOCALE
# missing in #else branch).  Defining d_setlocale enables USE_LOCALE and
# bypasses these issues, matching the behavior of 5.26 and earlier.
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -eq 28 ]; then
    cat >> "$WASM_DIR/hints/wasi.sh" << 'HINTS'
d_setlocale='define'
HINTS
fi

if [ "$ZEROPERL_SHRINK" = "full" ] && [ -f "$REPO_DIR/gen/hints-static-ext.fragment" ]; then
    cat "$REPO_DIR/gen/hints-static-ext.fragment" >> "$WASM_DIR/hints/wasi.sh"
fi

cd "$WASM_DIR"

# Apply patches
chmod u+w ./ext/File-Glob/bsd_glob.c
perl "$REPO_DIR/patches/patch_glob.pl"
chmod u-w ./ext/File-Glob/bsd_glob.c

# patch earlier versions of perl
if [ "$OLD_PERL" = 1 ]; then
    # mg_vtable.pl was introduced in 5.16; patch only exists there
    if [ -f "$WASM_DIR/regen/mg_vtable.pl" ]; then
        perl "$REPO_DIR/patches/patch_mg.pl"
    fi
fi

# patch 5.28.x locale bug: lc_numeric_set used outside #ifdef USE_LOCALE_NUMERIC
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -eq 28 ]; then
    perl "$REPO_DIR/patches/patch_sv_locale.pl"
fi

# Configure
wasiconfigure sh ./Configure -sde -Dhintfile=wasi

# Fix locale settings that Configure overrides
perl -pi -e "s/\Ad_perl_lc_all_uses_name_value_pairs=.*/d_perl_lc_all_uses_name_value_pairs='undef'/" config.sh
perl -pi -e "s/\Ad_perl_lc_all_separator=.*/d_perl_lc_all_separator='define'/" config.sh
perl -pi -e "s/\Aperl_lc_all_separator=.*/perl_lc_all_separator=';'/" config.sh
perl -pi -e "s/\Ad_perl_lc_all_category_positions_init=.*/d_perl_lc_all_category_positions_init='define'/" config.sh
perl -pi -e "s/\Aperl_lc_all_category_positions_init=.*/perl_lc_all_category_positions_init='{ 0, 1, 2, 3, 4, 5 }'/" config.sh

# Fix header/feature detection that failed due to cross-compilation
perl -pi -e "s/\Ai_time=.*/i_time='define'/" config.sh
perl -pi -e "s/\Ai_shadow=.*/i_shadow='undef'/" config.sh
perl -pi -e "s/\Ad_pwpasswd=.*/d_pwpasswd='undef'/" config.sh
perl -pi -e "s/\Ad_pwgecos=.*/d_pwgecos='undef'/" config.sh
perl -pi -e "s/\Ad_grpasswd=.*/d_grpasswd='undef'/" config.sh

if [ "$OLD_PERL" = 1 ]; then
    # Pre-5.20 specific cross-compilation fixes
    perl -pi -e "s/\Ai_systime=.*/i_systime='undef'/" config.sh
    perl -pi -e "s/\Ai_systimek=.*/i_systimek='undef'/" config.sh
    perl -pi -e "s/\Ai_systimes=.*/i_systimes='define'/" config.sh
    # Override static_ext to match our version-specific list
    perl -pi -e "s|\Astatic_ext=.*|static_ext='$WASI_STATIC_EXT'|" config.sh
fi

sh ./Configure -S

# Perl 5.40+ passes PERL_LC_ALL_SEPARATOR to STRLENs() in locale.c,
# which requires it to be a string literal. Configure generates it as a
# bare semicolon for backward compatibility with older usage patterns.
if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -ge 40 ]; then
    perl -pi -e 's/#define\s+PERL_LC_ALL_SEPARATOR\s+;/#define PERL_LC_ALL_SEPARATOR ";"/' config.h
fi

# Pre-5.20 post-Configure source fixes
if [ "$OLD_PERL" = 1 ]; then
    # Add include guards to proto.h for older Perl versions that lack them
    # (prevents duplicate declarations when proto.h is included from multiple places)
    if [ -f proto.h ] && ! grep -q 'PERL_PROTO_H_' proto.h 2>/dev/null; then
        printf '#ifndef PERL_PROTO_H_\n#define PERL_PROTO_H_\n' | cat - proto.h > proto.h.tmp && mv proto.h.tmp proto.h
        echo '#endif /* PERL_PROTO_H_ */' >> proto.h
    fi

    # Add missing PERL_ARGS_ASSERT macros for older Perl (5.16.x)
    # These are referenced by dquote_static.c but don't exist in the generated headers
    if [ -f embed.h ] && ! grep -q 'PERL_ARGS_ASSERT_REGCURLY' embed.h 2>/dev/null; then
        echo '#define PERL_ARGS_ASSERT_REGCURLY' >> embed.h
        echo '#define PERL_ARGS_ASSERT_GROK_BSLASH_O' >> embed.h
    fi

    # Fix setgid/setuid type mismatch: Perl's iperlsys.h passes UV (64-bit) to setgid
    # but WASI's gid_t is 32-bit, causing wasm-ld signature mismatch.
    if [ -f iperlsys.h ]; then
        perl "$REPO_DIR/patches/patch_iperlsys.pl"
    fi
fi

# Setup symlinks
ln -sf "$PWD/pod/perldelta.pod" .
ln -f "$PWD"/README.* .. 2>/dev/null || true

# Build
if [ "$OLD_PERL" = 1 ]; then
    if [ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -ge 20 ]; then
        # Perl 5.20: transitional build — Makefile handles hostperl symlink,
        # but needs the same uudmap fixes and Errno stub as older versions.

        # Pre-generate uudmap headers
        if [ -x "$NATIVE_DIR/generate_uudmap" ]; then
            "$NATIVE_DIR/generate_uudmap" uudmap.h bitcount.h mg_data.h
        fi
        touch uudmap.h bitcount.h mg_data.h
        # Neutralize generate_uudmap build/symlink rules in Makefile
        perl -pi -e '
            s|generate_uudmap\$\(HOST_EXE_EXT\)|/build/native/generate_uudmap|g;
            $_ = "" if /^\t-\@rm.*generate_uudmap/;
            $_ = "" if /\$\(LNS\).*generate_uudmap/;
            $_ = "" if /^\t.*\$\(CC\).*generate_uudmap.*-o.*generate_uudmap/;
            $_ = "" if m|^/build/native/generate_uudmap:|;
        ' Makefile

        # Stub out Errno.pm
        mkdir -p ext/Errno/blib/lib ext/Errno/blib/arch
        cp "$REPO_DIR/stubs/Errno.pm" ext/Errno/blib/lib/Errno.pm
        cp "$REPO_DIR/stubs/Errno.pm" lib/Errno.pm
        cat > ext/Errno/Makefile << 'ERRNOMF'
all ::
	@:
pure_all ::
	@:
clean ::
	@:
realclean ::
	@:
pm_to_blib ::
	@:
ERRNOMF
        touch ext/Errno/pm_to_blib

        # Build using host miniperl (Makefile already symlinks it)
        wasimake make -j"$NPROC" utilities PERL="$NATIVE_DIR/miniperl"
        wasimake make -j"$NPROC" -k RUN_PERL="$NATIVE_DIR/miniperl -Ilib -I." || true
        wasimake make -j"$NPROC" perl || true

        # Install
        wasimake make -k install || true
        if [ ! -d "/zeroperl/lib/$PERL_VERSION" ]; then
            echo "make install failed, installing lib manually..."
            mkdir -p /zeroperl/lib
            cp -r lib /zeroperl/lib/$PERL_VERSION
            mkdir -p /zeroperl/lib/$PERL_VERSION/wasm32-wasi
            cp lib/Config.pm lib/Config_heavy.pl /zeroperl/lib/$PERL_VERSION/wasm32-wasi/ 2>/dev/null || true
        fi
    else
        # Perl 5.16-5.18: fully manual cross-compilation flow

        # Pre-generate uudmap headers
        if [ -x "$NATIVE_DIR/generate_uudmap" ]; then
            "$NATIVE_DIR/generate_uudmap" uudmap.h bitcount.h mg_data.h
        fi
        touch uudmap.h bitcount.h mg_data.h
        perl -pi -e '
            s|generate_uudmap\$\(HOST_EXE_EXT\)|/build/native/generate_uudmap|g;
            $_ = "" if /^\t-\@rm.*generate_uudmap/;
            $_ = "" if /\$\(LNS\).*generate_uudmap/;
            $_ = "" if /^\t.*\$\(CC\).*generate_uudmap.*-o.*generate_uudmap/;
            $_ = "" if m|^/build/native/generate_uudmap:|;
        ' Makefile

        # Build miniperl (WASI target)
        wasimake make -j"$NPROC" miniperl

        # Save the WASI miniperl binary before replacing with native
        cp miniperl miniperl.wasm

        # Replace WASI miniperl with native miniperl so make steps can run perl scripts
        cp "$NATIVE_DIR/miniperl" miniperl

        # Stub out Errno.pm
        mkdir -p ext/Errno/blib/lib ext/Errno/blib/arch
        cp "$REPO_DIR/stubs/Errno.pm" ext/Errno/blib/lib/Errno.pm
        cp "$REPO_DIR/stubs/Errno.pm" lib/Errno.pm
        cat > ext/Errno/Makefile << 'ERRNOMF'
all ::
	@:
pure_all ::
	@:
clean ::
	@:
realclean ::
	@:
pm_to_blib ::
	@:
ERRNOMF
        touch ext/Errno/pm_to_blib

        # Build extensions and perl binary (use -k to continue past non-critical failures)
        wasimake make -j"$NPROC" -k RUN_PERL="$NATIVE_DIR/miniperl -Ilib -I." || true
        wasimake make -j"$NPROC" perl || true

        # Install using native miniperl
        wasimake make -k install || true
        if [ ! -d "/zeroperl/lib/$PERL_VERSION" ]; then
            echo "make install failed, installing lib manually..."
            mkdir -p /zeroperl/lib
            cp -r lib /zeroperl/lib/$PERL_VERSION
            mkdir -p /zeroperl/lib/$PERL_VERSION/wasm32-wasi
            cp lib/Config.pm lib/Config_heavy.pl /zeroperl/lib/$PERL_VERSION/wasm32-wasi/ 2>/dev/null || true
        fi
    fi
else
    # Modern Perl (5.22+): use host miniperl for build steps

    ln -sf "$NATIVE_DIR/generate_uudmap" generate_uudmap

    wasimake make -j"$NPROC" utilities PERL="$NATIVE_DIR/miniperl"
    wasimake make -j"$NPROC" -k RUN_PERL="$NATIVE_DIR/miniperl -Ilib -I." || true
    wasimake make -j"$NPROC" perl || true

    # Install using native miniperl
    wasimake make -k install || true
    if [ ! -d "/zeroperl/lib/$PERL_VERSION" ]; then
        echo "make install failed, installing lib manually..."
        mkdir -p /zeroperl/lib
        cp -r lib /zeroperl/lib/$PERL_VERSION
        mkdir -p /zeroperl/lib/$PERL_VERSION/wasm32-wasi
        cp lib/Config.pm lib/Config_heavy.pl /zeroperl/lib/$PERL_VERSION/wasm32-wasi/ 2>/dev/null || true
    fi
fi
