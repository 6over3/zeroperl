#!/bin/bash
# Test script for Linux/Unix Makefile validation

echo "=== Zeroperl Makefile Tests ==="

# Test 1: Syntax
echo -n "[TEST] Makefile syntax: "
if make -n help >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

# Test 2: Dependencies
echo -n "[TEST] Target dependencies: "
if make -n all >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

# Test 3: Help target
echo -n "[TEST] Help target: "
if make help >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

# Test 4: Clean targets
echo -n "[TEST] Clean targets: "
if make -n clean >/dev/null 2>&1 && make -n distclean >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

# Test 5: Required tools
echo -n "[TEST] Required tools: "
missing=""
command -v wget >/dev/null || missing="$missing wget"
command -v tar >/dev/null || missing="$missing tar"
command -v node >/dev/null || missing="$missing node"

if [ -z "$missing" ]; then
    echo "PASS"
else
    echo "FAIL (missing:$missing)"
fi

echo "Done."