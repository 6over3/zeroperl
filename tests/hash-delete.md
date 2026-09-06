# Native hash deletion regression

From the repository root, run:

```sh
python3 tests/test-hash-delete.py
```

Requires a C compiler, Python 3, and Perl with its development headers and
libperl. `PERL` and `CC` can select alternate toolchains.

The runner extracts the production `zeroperl_hash_delete` function verbatim,
then compiles it against real native Perl. This avoids the unrelated WASI
imports in the rest of the translation unit. The harness checks retained
values after Perl's temporary scope drains, exactly one DESTROY per object,
undef-valued keys, repeated/missing deletions, and invalid arguments.

The original implementation releases the retained value when temporaries drain,
causing failure or a freed-value diagnostic. This test does not exercise Asyncify
or promise-aware destructors; those require separate runtime/bridge changes.
