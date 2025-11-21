# zeroperl local build system

alternative to github actions for local development.

## quick start

```bash
# linux/unix/wsl
make help          # show available targets
make setup         # install wasi sdk and binaryen  
make all           # build complete zeroperl

# windows (testing only)
make help          # test makefile structure
test-cross-platform.bat  # run validation tests
```

## requirements

**linux/unix/wsl:**
- wget, tar, make, node, patch
- 4gb+ disk space for dependencies

**windows:**
- make (via chocolatey/msys2) for testing only
- use wsl or github actions for actual builds

## targets

- `all` - complete build pipeline
- `setup` - download wasi sdk and binaryen
- `native-perl` - build host perl for cross-compilation
- `wasi-perl` - cross-compile perl to webassembly
- `bundle` - create final zeroperl.wasm
- `clean` - remove build artifacts
- `distclean` - remove all downloads

## Configuration

Edit Makefile variables:
```makefile
PERL_VERSION = 5.40.0
WASI_SDK_VERSION = 25.0
BUILD_EXIFTOOL = true
```