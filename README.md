zeroperl is an experimental build of Perl5 in a sandboxed, self-contained WebAssembly module.

Read the full blog [here](https://andrews.substack.com/p/zeroperl-sandboxed-perl-with-webassembly)

## Build

Requires Docker or Apple Container (macOS).

**Docker:**
```bash
docker build -t zeroperl .
mkdir -p output
docker run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
```

**Apple Container (macOS):**
```bash
container build -t zeroperl .
mkdir -p output
container run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
```

Output in `./output/`:
- `zeroperl.wasm` — reactor with asyncify
- `zeroperl_reactor.wasm` — reactor without asyncify
- `perl-wasi-prefix/` — Perl library prefix
- `exiftool.min.pl` — minified ExifTool (if enabled)

### Build args

**Docker:**
```bash
docker build --build-arg PERL_VERSION=5.40.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

**Apple Container:**
```bash
container build --build-arg PERL_VERSION=5.40.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

<details>
<summary>Available build arguments</summary>

| Arg | Default | |
|-----|---------|--|
| `PERL_VERSION` | `5.42.0` | Perl source version |
| `EXIFTOOL_VERSION` | `13.42` | ExifTool version |
| `BUILD_EXIFTOOL` | `true` | Include ExifTool |
| `STACK_SIZE` | `8388608` | WASM stack (bytes) |
| `INITIAL_MEMORY` | `33554432` | WASM initial memory (bytes) |
| `ASYNCIFY` | `true` | Enable asyncify |
| `TRIM` | `true` | Strip unused modules |

</details>

### Iterating on stubs/zeroperl.c

Build from `final` stage to reuse cached wasi-perl:

**Docker:**
```bash
docker build --target final -t zeroperl .
```

**Apple Container:**
```bash
container build --target final -t zeroperl .
```

## Usage

> **Note:** The first argument passed to Perl **must** be `zeroperl`.
> Depending on your runtime, you may need to map `/dev/null` as a preopen.
