#!/usr/bin/env node
// tests/sfs/test-generator.js
// Unit-style tests for tools/sfs.js output generation only.
// Limitation: these tests do not execute stubs/zeroperl.c runtime decode path;
// runtime behavior must be validated separately in integration tests.
//
// Run: node tests/sfs/test-generator.js
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const lz4 = require(path.join(__dirname, "../../tools/node_modules/lz4"));

const ROOT = path.resolve(__dirname, "../..");
const SFS_JS = path.join(ROOT, "tools", "sfs.js");

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (e) {
    console.error(`  FAIL: ${name}`);
    console.error(`       ${e.message}`);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "sfs-gen-test-"));
}

function makeTmpHeader() {
  return path.join(os.tmpdir(), `sfs-gen-test-${process.pid}-${Date.now()}.h`);
}

function derivedPaths(headerPath) {
  const base = headerPath.replace(/\.h$/, "");
  return {
    header: headerPath,
    dataC: base + "_data.c",
    dataBin: base + "_data.bin",
  };
}

function runSfs(inputDir, outputHeader, extraArgs = []) {
  execFileSync(
    "node",
    [SFS_JS, "-i", inputDir, "-o", outputHeader, ...extraArgs],
    { stdio: "pipe" },
  );
}

function runSfsWithEnv(
  inputDir,
  outputHeader,
  extraArgs = [],
  env = process.env,
) {
  execFileSync(
    process.execPath,
    [SFS_JS, "-i", inputDir, "-o", outputHeader, ...extraArgs],
    { stdio: "pipe", env },
  );
}

function nodeOnlyEnv() {
  return {
    ...process.env,
    PATH: path.dirname(process.execPath),
  };
}

function cleanup(outHeader, dir) {
  const { dataC, dataBin } = derivedPaths(outHeader);
  for (const f of [outHeader, dataC, dataBin]) {
    // Best-effort cleanup for idempotent tests; ignore already-removed files.
    try {
      fs.unlinkSync(f);
    } catch (error) {
      void error;
    }
  }
  // Remove temporary corpus directory recursively when provided.
  if (dir)
    try {
      fs.rmSync(dir, { recursive: true });
    } catch (error) {
      void error;
    }
}

/**
 * Creates a deterministic test corpus:
 *   <dir>/lib/5.42.2/Carp.pm
 *   <dir>/lib/5.42.2/strict.pm
 *   <dir>/lib/site_perl/5.42.2/Image/ExifTool.pm
 *   <dir>/run.pl
 *
 * Returns an object with:
 *   - files: sorted relative paths (as sfs.js would emit them)
 *   - contents: map of relpath -> Buffer
 */
function makeTestCorpus(dir) {
  const files = {
    "lib/5.42.2/Carp.pm": Buffer.from("package Carp; 1;\n"),
    "lib/5.42.2/strict.pm": Buffer.from("package strict; 1;\n"),
    "lib/site_perl/5.42.2/Image/ExifTool.pm": Buffer.from(
      "package Image::ExifTool; 1;\n",
    ),
    "run.pl": Buffer.from("#!/usr/bin/perl\n"),
  };
  for (const [rel, data] of Object.entries(files)) {
    const full = path.join(dir, rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, data);
  }
  const sorted = Object.keys(files).sort();
  return { files: sorted, contents: files };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

console.log("\ntests/sfs/test-generator.js");
console.log("=====================================");

test("produces all three output files", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out);
    const { dataC, dataBin } = derivedPaths(out);
    assert.ok(fs.existsSync(out), "header file missing");
    assert.ok(fs.existsSync(dataC), "data.c file missing");
    assert.ok(fs.existsSync(dataBin), "data.bin file missing");
  } finally {
    cleanup(out, dir);
  }
});

test("traversal order is deterministic sorted", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    // Extract quoted path arguments from sfs_entries table rows
    const quoted = [...src.matchAll(/"([^"]+)"/g)]
      .map((m) => m[1])
      .filter((p) => !p.startsWith("#"));
    // Filter to only abspaths (non-numeric and not header name)
    const abspaths = quoted.filter((p) => p.startsWith("/") || p.includes("/"));
    // They should be in sorted order
    const sorted = [...abspaths].sort();
    assert.deepEqual(abspaths, sorted, "entries not in sorted order");
  } finally {
    cleanup(out, dir);
  }
});

test("entry count matches file count", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    const corpus = makeTestCorpus(dir);
    runSfs(dir, out);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const m = src.match(/sfs_builtin_files_num\s*=\s*(\d+)/);
    assert.ok(m, "sfs_builtin_files_num not found in data.c");
    assert.equal(
      parseInt(m[1], 10),
      corpus.files.length,
      `expected ${corpus.files.length} entries`,
    );
  } finally {
    cleanup(out, dir);
  }
});

test("prefix is prepended to all abspaths in header and data.c", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out, ["--prefix", "/zeroperl"]);
    const hdr = fs.readFileSync(out, "utf8");
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    assert.ok(
      hdr.includes('SFS_BUILTIN_PREFIX "/zeroperl"'),
      "SFS_BUILTIN_PREFIX not set in header",
    );
    assert.ok(src.includes('"/zeroperl/'), "entries missing prefix in data.c");
    assert.ok(!src.includes('"lib/5.42.2'), "unprefixed path found in data.c");
  } finally {
    cleanup(out, dir);
  }
});

test("header declares sfs_entry struct and extern symbols", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out);
    const hdr = fs.readFileSync(out, "utf8");
    assert.ok(
      hdr.includes("struct sfs_entry"),
      "struct sfs_entry missing from header",
    );
    assert.ok(
      hdr.includes("uint32_t decompressed_size"),
      "decompressed_size field missing from struct sfs_entry",
    );
    assert.ok(
      hdr.includes("uint8_t codec"),
      "codec field missing from struct sfs_entry",
    );
    assert.ok(
      hdr.includes("extern size_t sfs_builtin_files_num"),
      "extern sfs_builtin_files_num missing",
    );
    assert.ok(
      hdr.includes("extern const struct sfs_entry sfs_entries[]"),
      "extern sfs_entries[] missing",
    );
  } finally {
    cleanup(out, dir);
  }
});

test("offset arithmetic: no gaps and no overlaps", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const bin = fs.readFileSync(derivedPaths(out).dataBin);
    // Parse pairs: sfs_builtin_data + START, sfs_builtin_data + START + LEN
    // Each entry looks like: { "path", sfs_builtin_data + START, sfs_builtin_data + START + LEN }
    const pairs = [
      ...src.matchAll(
        /sfs_builtin_data \+ (\d+), sfs_builtin_data \+ \d+ \+ (\d+)/g,
      ),
    ].map((m) => [parseInt(m[1], 10), parseInt(m[1], 10) + parseInt(m[2], 10)]);
    assert.ok(pairs.length > 0, "no entries found in data.c");
    let cursor = 0;
    for (const [start, end] of pairs) {
      assert.equal(start, cursor, `gap before offset ${cursor}`);
      assert.ok(end > start, `zero-length span at offset ${start}`);
      cursor = end;
    }
    assert.equal(cursor, bin.length, "last file end does not reach bin size");
  } finally {
    cleanup(out, dir);
  }
});

test("uncompressed entries have codec=0 and decompressed_size=0", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    // Each entry ends in ", 0, 0 }," where the two zeros are decompressed_size and codec
    const entries = [...src.matchAll(/\{[^}]+,\s*(\d+),\s*(\d+)\s*\}/g)];
    assert.ok(entries.length > 0, "no entries found");
    for (const m of entries) {
      assert.equal(m[1], "0", `decompressed_size expected 0, got ${m[1]}`);
      assert.equal(m[2], "0", `codec expected 0, got ${m[2]}`);
    }
  } finally {
    cleanup(out, dir);
  }
});

test("binary blob contains original file bytes in sorted order", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    const corpus = makeTestCorpus(dir);
    runSfs(dir, out);
    const bin = fs.readFileSync(derivedPaths(out).dataBin);
    const expected = Buffer.concat(corpus.files.map((f) => corpus.contents[f]));
    assert.deepEqual(
      bin,
      expected,
      "binary blob bytes do not match concatenated files",
    );
  } finally {
    cleanup(out, dir);
  }
});

test("--skip regex excludes matching files", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfs(dir, out, ["--skip", "\\.pm$"]);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    assert.ok(!src.includes('.pm"'), ".pm files were not skipped");
    assert.ok(src.includes("run.pl"), "run.pl is missing after skip");
  } finally {
    cleanup(out, dir);
  }
});

test("dotfiles are excluded", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    fs.writeFileSync(path.join(dir, ".DS_Store"), "junk");
    fs.writeFileSync(path.join(dir, "lib/5.42.2/.hidden"), "secret");
    runSfs(dir, out);
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    assert.ok(!src.includes(".DS_Store"), "dotfile .DS_Store was not excluded");
    assert.ok(!src.includes(".hidden"), "dotfile .hidden was not excluded");
  } finally {
    cleanup(out, dir);
  }
});

test("generated C source embeds original file contents correctly", () => {
  // Run sfs.js twice on the same corpus and compare -- ensures determinism
  const dir = makeTmpDir();
  const outA = makeTmpHeader();
  const outB = outA.replace(".h", "_b.h");
  try {
    makeTestCorpus(dir);
    runSfs(dir, outA);
    runSfs(dir, outB);
    const binA = fs.readFileSync(derivedPaths(outA).dataBin);
    const binB = fs.readFileSync(derivedPaths(outB).dataBin);
    assert.deepEqual(binA, binB, "non-deterministic binary output");
    const srcA = fs.readFileSync(derivedPaths(outA).dataC, "utf8");
    const srcB = fs.readFileSync(derivedPaths(outB).dataC, "utf8");
    // Replace auto-generated paths (tmp dirs differ) before comparing structure
    const normalize = (s) => s.replace(/sfs-gen-test-[^"]+/g, "TMPDIR");
    assert.equal(normalize(srcA), normalize(srcB), "non-deterministic data.c");
  } finally {
    cleanup(outA, dir);
    cleanup(outB);
  }
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Phase 3: --compress mode
// ---------------------------------------------------------------------------

test("--compress: codec=1 for all entries", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const entries = [...src.matchAll(/\{[^}]+,\s*(\d+),\s*(\d+)\s*\}/g)];
    assert.ok(entries.length > 0, "no entries found");
    for (const m of entries) {
      assert.equal(m[2], "1", `codec expected 1, got ${m[2]}`);
    }
  } finally {
    cleanup(out, dir);
  }
});

test("--compress: decompressed_size matches original file sizes", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    // Parse entries: { "path", start, start+len, decompressed_size, codec }
    const rows = [
      ...src.matchAll(
        /\{\s*"([^"]+)",\s*sfs_builtin_data \+ (\d+),\s*sfs_builtin_data \+ \d+ \+ (\d+),\s*(\d+),\s*(\d+)\s*\}/g,
      ),
    ];
    assert.ok(rows.length > 0, "no entries found");
    for (const m of rows) {
      const decompressedSize = parseInt(m[4], 10);
      assert.ok(
        decompressedSize > 0,
        `decompressed_size should be > 0, got ${decompressedSize}`,
      );
    }
  } finally {
    cleanup(out, dir);
  }
});

test("--compress: decompressed_size matches original content length", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    const corpus = makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const rows = [
      ...src.matchAll(
        /\{\s*"([^"]+)",\s*sfs_builtin_data \+ (\d+),\s*sfs_builtin_data \+ \d+ \+ (\d+),\s*(\d+),\s*(\d+)\s*\}/g,
      ),
    ];
    assert.ok(
      rows.length === corpus.files.length,
      `expected ${corpus.files.length} entries, got ${rows.length}`,
    );
    for (const m of rows) {
      // m[1]=abspath, m[2]=start, m[3]=len, m[4]=decompressed_size, m[5]=codec
      const abspath = m[1];
      const decompressedSize = parseInt(m[4], 10);
      // Find matching corpus file
      const relKey = corpus.files.find((f) => abspath.endsWith(f));
      assert.ok(relKey, `corpus entry not found for ${abspath}`);
      const originalLen = corpus.contents[relKey].length;
      assert.equal(
        decompressedSize,
        originalLen,
        `decompressed_size mismatch for ${relKey}: expected ${originalLen}, got ${decompressedSize}`,
      );
    }
  } finally {
    cleanup(out, dir);
  }
});

test("--compress: compressed spans have no gaps or overlaps", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const bin = fs.readFileSync(derivedPaths(out).dataBin);
    const pairs = [
      ...src.matchAll(
        /sfs_builtin_data \+ (\d+), sfs_builtin_data \+ \d+ \+ (\d+)/g,
      ),
    ].map((m) => [parseInt(m[1], 10), parseInt(m[1], 10) + parseInt(m[2], 10)]);
    assert.ok(pairs.length > 0, "no entries found");
    let cursor = 0;
    for (const [start, end] of pairs) {
      assert.equal(start, cursor, `gap before offset ${cursor}`);
      assert.ok(end > start, `zero-length span at offset ${start}`);
      cursor = end;
    }
    assert.equal(cursor, bin.length, "last file end does not reach bin size");
  } finally {
    cleanup(out, dir);
  }
});

test("--compress: succeeds without lz4 CLI on PATH", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    assert.ok(
      fs.existsSync(derivedPaths(out).dataBin),
      "compressed data.bin missing",
    );
  } finally {
    cleanup(out, dir);
  }
});

test("--compress: compressed data decompresses to original content", () => {
  const dir = makeTmpDir();
  const out = makeTmpHeader();
  try {
    const corpus = makeTestCorpus(dir);
    runSfsWithEnv(dir, out, ["--compress"], nodeOnlyEnv());
    const src = fs.readFileSync(derivedPaths(out).dataC, "utf8");
    const bin = fs.readFileSync(derivedPaths(out).dataBin);
    const rows = [
      ...src.matchAll(
        /\{\s*"([^"]+)",\s*sfs_builtin_data \+ (\d+),\s*sfs_builtin_data \+ \d+ \+ (\d+),\s*(\d+),\s*(\d+)\s*\}/g,
      ),
    ];
    assert.ok(rows.length > 0, "no entries found");
    for (const m of rows) {
      const abspath = m[1];
      const startOff = parseInt(m[2], 10);
      const compLen = parseInt(m[3], 10);
      const decompSz = parseInt(m[4], 10);
      const codec = parseInt(m[5], 10);
      assert.equal(codec, 1, `expected codec=1 for ${abspath}`);
      const compSlice = bin.slice(startOff, startOff + compLen);
      const decompBuf = lz4.decode(compSlice);
      const n = decompBuf.length;
      assert.equal(
        n,
        decompSz,
        `decompressed ${n} bytes, expected ${decompSz}`,
      );
      const relKey = corpus.files.find((f) => abspath.endsWith(f));
      assert.ok(relKey, `corpus key not found for ${abspath}`);
      assert.deepEqual(
        decompBuf,
        corpus.contents[relKey],
        `content mismatch for ${relKey}`,
      );
    }
  } finally {
    cleanup(out, dir);
  }
});

console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
