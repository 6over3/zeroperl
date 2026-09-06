#!/usr/bin/env python3
"""Compile the production function against real native libperl, without WASI."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "stubs/zeroperl.c").read_text()
start = source.index('ZEROPERL_API("zeroperl_hash_delete")')
end = source.index("\n//! Clear all entries", start)
perl = os.environ.get("PERL", "perl")

def flags(kind):
    return shlex.split(subprocess.check_output(
        [perl, "-MExtUtils::Embed", "-e", kind], text=True))

with tempfile.TemporaryDirectory(prefix="zeroperl-hash-delete-") as directory:
    temp = Path(directory)
    (temp / "hash-delete-function.inc").write_text(source[start:end])
    binary = temp / "test"
    subprocess.run([*shlex.split(os.environ.get("CC", "cc")),
                    *flags("ccopts"), "-g", "-O0", "-I", str(temp),
                    str(root / "tests/hash-delete.c"), "-o", str(binary),
                    *flags("ldopts")], check=True)
    subprocess.run([str(binary)], check=True)
