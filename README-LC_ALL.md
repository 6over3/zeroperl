# lc_all=1 requirement in zeroperl

## the problem

zeroperl crashes on startup unless `LC_ALL=1` is set as an environment variable. this is a known issue documented in [perl/perl5#22375](https://github.com/perl/perl5/issues/22375). it is a **security model impedance mismatch** b/t perl posix and wasi's sandbox.

## root cause

**wasi locale limitations:**
- wasi provides incomplete posix locale support
- missing `setlocale()`, `localeconv()`, and locale data files
- no access to system locale directories (`/usr/share/locale/`)

**perl's locale initialization:**
- perl assumes full posix locale environment during startup
- attempts to initialize locale categories (lc_numeric, lc_time, etc.)
- crashes when wasi's incomplete locale functions fail

## the workaround

setting `LC_ALL=1` forces perl to:
1. recognize an invalid locale specification
2. fall back to "c" locale (minimal/safe locale)
3. skip problematic locale detection code
4. start successfully with basic locale support

## usage examples

```bash
# command line
lc_all=1 wasmtime zeroperl.wasm zeroperl -e 'print "hello\n"'

# in scripts
export lc_all=1
wasmtime zeroperl.wasm zeroperl script.pl

# node.js
process.env.lc_all = '1';
```

## technical details

this is an **impedance mismatch** between:
- **perl's expectations:** full posix locale system
- **wasi's reality:** sandboxed environment with minimal libc

the `LC_ALL=1` hack exploits perl's locale fallback mechanism to bypass wasi's incomplete locale implementation.

## alternative solutions

future fixes might include:
- patching perl's locale initialization for wasi
- implementing stub locale functions in wasi
- compile-time disabling of locale features

for now, `LC_ALL=1` remains the required workaround.