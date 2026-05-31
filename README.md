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
- `zeroperl_command.wasm` — command-compatible module with a returnable `_start` export
- `perl-wasi-prefix/` — Perl library prefix
- `exiftool.min.pl` — minified ExifTool (if enabled)

### Build args

**Docker:**
```bash
docker build --build-arg PERL_VERSION=5.42.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

**Apple Container:**
```bash
container build --build-arg PERL_VERSION=5.42.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

<details>
<summary>Available build arguments</summary>

| Arg | Default | |
|-----|---------|--|
| `PERL_VERSION` | `5.42.0` | Perl source version |
| `EXIFTOOL_VERSION` | `13.58` | ExifTool version |
| `BUILD_EXIFTOOL` | `true` | Include ExifTool |
| `STACK_SIZE` | `8388608` | WASM stack (bytes) |
| `INITIAL_MEMORY` | `33554432` | WASM initial memory (bytes) |
| `ASYNCIFY` | `true` | Enable asyncify |
| `ENABLE_HOST_CALLBACKS` | `false` | Import `env.call_host_function` for host-registered Perl callbacks |
| `TRIM` | `true` | Strip unused modules |

</details>

By default, the generated WebAssembly modules only require WASI imports. Use
`zeroperl.wasm` when embedding zeroperl through the exported `zeroperl_*` API.
Use `zeroperl_command.wasm` for loaders that call `instance.exports._start`,
such as drop-in replacements for the hosted `perl.objex.ai/zeroperl-1.0.0.wasm`
artifact. Its `_start` export reads WASI arguments but returns normally instead
of relying on `proc_exit`, which keeps browser loaders with simple WASI shims
from trapping after the Perl run completes. If your host uses
`zeroperl_register_function` or `zeroperl_register_method`, build with
`--build-arg ENABLE_HOST_CALLBACKS=true` and provide `env.call_host_function`
when instantiating the module.

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

## Testing

The easiest way to test a new build of `zeroperl.wasm` is to clone the TypeScript wrapper and run its test suite:

```bash
git clone https://github.com/6over3/zeroperl-ts
```

See the [zeroperl-ts README](https://github.com/6over3/zeroperl-ts) for details.

## Usage

> **Note:** The first argument passed to Perl **must** be `zeroperl`.
> Depending on your runtime, you may need to map `/dev/null` as a preopen.
