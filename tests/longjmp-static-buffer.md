# Native longjmp regression

Run from the repository root with Clang and AddressSanitizer:

```sh
clang -std=c11 -g -O1 -fsanitize=address -Wno-unknown-attributes tests/longjmp-static-buffer.c -o /tmp/zeroperl-longjmp-test
/tmp/zeroperl-longjmp-test
```

The harness includes the production state machine and substitutes native hooks
for the Asyncify imports and stack-pointer operations. It exercises initial
capture and 100 longjmp recovery cycles. Before the fix, AddressSanitizer reports
an attempted free of non-allocated static storage on the first recovery.
This isolates ownership; it does not emulate WASM stack unwinding.
