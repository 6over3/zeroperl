#!/usr/bin/env node

import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { MemoryFileSystem, ZeroPerl } from "@6over3/zeroperl-ts";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function printUsage() {
  console.log("Usage: wasm-smoke.mjs <wasmPath> [prefixDir|exiftoolPath]");
  console.log("  wasmPath     Path to zeroperl.wasm");
  console.log("  prefixDir    External prefix directory (full prefix or test lib)");
  console.log("  exiftoolPath Path to exiftool.min.pl (embedded prefix + ExifTool smoke)");
}

function decodeChunk(chunk) {
  if (typeof chunk === "string") return chunk;
  if (chunk instanceof Uint8Array) return new TextDecoder().decode(chunk);
  return String(chunk);
}

function extractIncLines(output) {
  const match = output.match(/__INC_BEGIN__\n([\s\S]*?)__INC_END__/);
  if (!match) return [];
  return match[1].split("\n").map((l) => l.trim()).filter(Boolean);
}

function assertEmbeddedInc(incLines) {
  const versioned = incLines.some((l) => /\/zeroperl\/lib\/\d+\.\d+\.\d+$/.test(l));
  const arch = incLines.some((l) => /\/zeroperl\/lib\/\d+\.\d+\.\d+\/wasm32-wasi$/.test(l));
  if (!versioned) throw new Error("Missing embedded versioned lib dir in @INC");
  if (!arch) throw new Error("Missing embedded arch subdir in @INC");
}

async function mountDirectory(fileSystem, sourceDir, targetDir) {
  const entries = await readdir(sourceDir);
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry);
    const targetPath = path.posix.join(targetDir, entry);
    const st = await stat(sourcePath);
    if (st.isDirectory()) {
      fileSystem.ensureDir(targetPath);
      await mountDirectory(fileSystem, sourcePath, targetPath);
    } else if (st.isFile()) {
      const content = await readFile(sourcePath);
      fileSystem.addFile(targetPath, content);
    }
  }
}

async function detectPrefixMountPoint(prefixDir) {
  const libDir = path.join(prefixDir, "lib");
  try {
    const entries = await readdir(libDir);
    if (entries.some((e) => /^\d+\.\d+\.\d+$/.test(e))) {
      return "/prefix";
    }
  } catch {}
  return "/lib";
}

async function findPerlVersion(prefixDir) {
  const libDir = path.join(prefixDir, "lib");
  const entries = await readdir(libDir);
  for (const entry of entries) {
    if (/^\d+\.\d+\.\d+$/.test(entry)) {
      return entry;
    }
  }
  return null;
}

function decodeBase64File(content) {
  return Uint8Array.from(Buffer.from(content.replace(/\s+/g, ""), "base64"));
}

function assertRunSuccess(label, result, stdout, stderr) {
  if (result.success) return;
  throw new Error(
    [
      `${label} failed with exit code ${result.exitCode}`,
      result.error ? `run error: ${result.error}` : "",
      stdout ? `stdout:\n${stdout}` : "",
      stderr ? `stderr:\n${stderr}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
  );
}

function parseJsonOutput(label, stdout, stderr) {
  const trimmed = stdout.trim();
  if (!trimmed) throw new Error(`${label} produced empty stdout\nstderr:\n${stderr}`);
  try {
    return JSON.parse(trimmed);
  } catch (err) {
    throw new Error(
      [
        `${label} produced invalid JSON`,
        err instanceof Error ? err.message : String(err),
        `stdout:\n${stdout}`,
        stderr ? `stderr:\n${stderr}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    );
  }
}

function assertStringOutput(label, stdout, stderr) {
  if (stdout.trim()) return;
  throw new Error(`${label} produced empty stdout\nstderr:\n${stderr}`);
}

async function runExifTool(perl, exiftoolScript, smokeFiles, args) {
  const fileSystem = new MemoryFileSystem();
  fileSystem.addFile("/work/exiftool.min.pl", exiftoolScript);
  fileSystem.addFile("/work/sample.jpg", smokeFiles.sampleJpg);
  fileSystem.addFile("/work/sample.tiff", smokeFiles.sampleTiff);
  fileSystem.addFile("/work/sample.xmp", smokeFiles.sampleXmp);

  let stdout = "";
  let stderr = "";

  const runPerl = await ZeroPerl.create({
    fetch: perl._fetch,
    fileSystem,
    stdout: (chunk) => {
      const text = decodeChunk(chunk);
      stdout += text;
    },
    stderr: (chunk) => {
      const text = decodeChunk(chunk);
      stderr += text;
    },
  });

  try {
    const result = await runPerl.runFile("/work/exiftool.min.pl", args);
    runPerl.flush();
    return { result, stdout, stderr };
  } finally {
    runPerl.dispose();
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    printUsage();
    process.exit(args.length === 0 ? 1 : 0);
  }

  if (args.length > 2) {
    printUsage();
    process.exit(1);
  }

  const wasmPath = args[0];
  const extraPath = args[1];

  let prefixDir = "";
  let exiftoolPath = "";

  if (extraPath) {
    const st = await stat(extraPath);
    if (st.isDirectory()) {
      prefixDir = extraPath;
    } else {
      exiftoolPath = extraPath;
    }
  }

  const wasmBinary = await readFile(wasmPath);
  const fileSystem = new MemoryFileSystem();
  // /work is required because core-smoke.pl writes to /work/_smoke_tmp via IO::File
  fileSystem.ensureDir("/work");

  // Always mount tests/smoke/lib so Core::TestMod is available for core-mod-smoke.pl
  await mountDirectory(fileSystem, path.join(repoRoot, "tests", "smoke", "lib"), "/lib");

  let mountPoint = "";
  let perlVersion = "";
  if (prefixDir) {
    mountPoint = await detectPrefixMountPoint(prefixDir);
    await mountDirectory(fileSystem, prefixDir, mountPoint);
    if (mountPoint === "/prefix") {
      perlVersion = await findPerlVersion(prefixDir);
    }
  }

  const env = {};
  if (mountPoint === "/prefix" && perlVersion) {
    env.PERL5LIB = `/prefix/lib/${perlVersion}/wasm32-wasi:/prefix/lib/${perlVersion}:/lib`;
  } else {
    env.PERL5LIB = "/lib";
  }

  let stdoutBuffer = "";
  let stderrBuffer = "";

  const perl = await ZeroPerl.create({
    fetch: async () => new Response(wasmBinary, { headers: { "content-type": "application/wasm" } }),
    fileSystem,
    stdout: (chunk) => {
      const text = decodeChunk(chunk);
      stdoutBuffer += text;
      process.stdout.write(text);
    },
    stderr: (chunk) => {
      const text = decodeChunk(chunk);
      stderrBuffer += text;
      process.stderr.write(text);
    },
    env: Object.keys(env).length ? env : undefined,
  });

  console.log("ZEROPERL_INIT_OK");

  // Verify @INC
  const incScript = exiftoolPath
    ? `
      print "__INC_BEGIN__\\n";
      print "$_\\n" for @INC;
      print "__INC_END__\\n";
      require File::Glob;
      require Image::ExifTool;
      require Image::ExifTool::XMP;
      print "__MODULE_OK__\\n";
    `
    : 'print "__INC_BEGIN__\n"; print "$_\n" for @INC; print "__INC_END__\n";';

  const incResult = await perl.eval(incScript);
  perl.flush();
  if (!incResult.success || incResult.exitCode !== 0) {
    throw new Error(`@INC verification failed: ${incResult.error || "unknown error"}`);
  }
  const incLines = extractIncLines(stdoutBuffer);
  assertEmbeddedInc(incLines);
  console.log("EMBEDDED_INC_OK");

  if (exiftoolPath && !stdoutBuffer.includes("__MODULE_OK__")) {
    throw new Error(`ExifTool module load marker missing\nstdout:\n${stdoutBuffer}\nstderr:\n${stderrBuffer}`);
  }

  if (prefixDir) {
    if (mountPoint === "/prefix") {
      const hasExternal = incLines.some((l) => l.startsWith("/prefix/lib/"));
      if (!hasExternal) throw new Error("Missing external /prefix/lib/ in @INC");
    } else {
      const hasExternal = incLines.some((l) => l.startsWith(mountPoint));
      if (!hasExternal) throw new Error(`Missing external ${mountPoint} in @INC`);
    }
    console.log("EXTERNAL_INC_OK");
  }

  // Always verify /lib is in @INC so Core::TestMod resolves
  if (!incLines.includes("/lib")) throw new Error("Missing /lib in @INC");
  console.log("TESTLIB_INC_OK");

  // Core smoke
  const coreSmoke = await readFile(path.join(repoRoot, "tests", "smoke", "core-smoke.pl"), "utf8");
  const coreResult = await perl.eval(coreSmoke);
  perl.flush();
  if (!coreResult.success || coreResult.exitCode !== 0) {
    throw new Error(`core-smoke.pl failed: ${coreResult.error || "unknown error"}`);
  }
  if (!stdoutBuffer.includes("CORE_SMOKE_OK")) throw new Error("core-smoke.pl did not print CORE_SMOKE_OK");
  console.log("CORE_SMOKE_PL_OK");

  // Core mod smoke
  const coreModSmoke = await readFile(path.join(repoRoot, "tests", "smoke", "core-mod-smoke.pl"), "utf8");
  const modResult = await perl.eval(coreModSmoke);
  perl.flush();
  if (!modResult.success || modResult.exitCode !== 0) {
    throw new Error(`core-mod-smoke.pl failed: ${modResult.error || "unknown error"}`);
  }
  if (!stdoutBuffer.includes("CORE_SMOKE_OK")) throw new Error("core-mod-smoke.pl did not print CORE_SMOKE_OK");
  console.log("CORE_MOD_SMOKE_PL_OK");

  // ExifTool smoke tests
  if (exiftoolPath) {
    const exiftoolScript = await readFile(exiftoolPath);
    const [sampleJpgB64, sampleTiffB64, sampleXmp] = await Promise.all([
      readFile(path.join(repoRoot, "tests", "smoke", "sample.jpg.b64"), "utf8"),
      readFile(path.join(repoRoot, "tests", "smoke", "sample.tiff.b64"), "utf8"),
      readFile(path.join(repoRoot, "tests", "smoke", "sample.xmp")),
    ]);
    const smokeFiles = {
      sampleJpg: decodeBase64File(sampleJpgB64),
      sampleTiff: decodeBase64File(sampleTiffB64),
      sampleXmp: sampleXmp,
    };

    // ExifTool -ver
    const versionRun = await runExifTool(perl, exiftoolScript, smokeFiles, ["-ver"]);
    assertRunSuccess("exiftool -ver", versionRun.result, versionRun.stdout, versionRun.stderr);
    assertStringOutput("exiftool -ver", versionRun.stdout, versionRun.stderr);
    console.log("EXIFTOOL_VER_OK");

    // ExifTool -json sample.jpg
    const jsonRun = await runExifTool(perl, exiftoolScript, smokeFiles, ["-json", "/work/sample.jpg"]);
    assertRunSuccess("exiftool -json sample.jpg", jsonRun.result, jsonRun.stdout, jsonRun.stderr);
    const jsonResult = parseJsonOutput("exiftool -json sample.jpg", jsonRun.stdout, jsonRun.stderr);
    if (!Array.isArray(jsonResult) || jsonResult.length !== 1) {
      throw new Error(`expected one JSON result for sample.jpg\nstdout:\n${jsonRun.stdout}`);
    }
    const sampleFields = jsonResult[0];
    if (!sampleFields || typeof sampleFields !== "object") {
      throw new Error(`missing JSON fields for sample.jpg\nstdout:\n${jsonRun.stdout}`);
    }
    if (!sampleFields.ExifToolVersion) {
      throw new Error(`missing ExifToolVersion in sample.jpg JSON\nstdout:\n${jsonRun.stdout}`);
    }
    if (sampleFields.FileType !== "JPEG") {
      throw new Error(`expected FileType=JPEG, got ${String(sampleFields.FileType)}`);
    }
    if (sampleFields.MIMEType !== "image/jpeg") {
      throw new Error(`expected MIMEType=image/jpeg, got ${String(sampleFields.MIMEType)}`);
    }
    console.log("EXIFTOOL_JPEG_OK");

    // ExifTool -json -FileType -MIMEType sample.jpg
    const multipleArgsRun = await runExifTool(perl, exiftoolScript, smokeFiles, ["-json", "-FileType", "-MIMEType", "/work/sample.jpg"]);
    assertRunSuccess("exiftool -json -FileType -MIMEType sample.jpg", multipleArgsRun.result, multipleArgsRun.stdout, multipleArgsRun.stderr);
    const multipleArgsResult = parseJsonOutput("exiftool -json -FileType -MIMEType sample.jpg", multipleArgsRun.stdout, multipleArgsRun.stderr);
    if (!Array.isArray(multipleArgsResult) || multipleArgsResult.length !== 1) {
      throw new Error(`expected one JSON result for -FileType -MIMEType sample.jpg\nstdout:\n${multipleArgsRun.stdout}`);
    }
    const selectedFields = multipleArgsResult[0];
    if (!selectedFields || typeof selectedFields !== "object") {
      throw new Error(`missing selected JSON fields\nstdout:\n${multipleArgsRun.stdout}`);
    }
    if (selectedFields.FileType !== "JPEG") {
      throw new Error(`expected selected FileType=JPEG, got ${String(selectedFields.FileType)}`);
    }
    if (selectedFields.MIMEType !== "image/jpeg") {
      throw new Error(`expected selected MIMEType=image/jpeg, got ${String(selectedFields.MIMEType)}`);
    }
    console.log("EXIFTOOL_SELECTED_OK");

    // ExifTool -json sample.tiff
    const tiffRun = await runExifTool(perl, exiftoolScript, smokeFiles, ["-json", "/work/sample.tiff"]);
    assertRunSuccess("exiftool sample.tiff", tiffRun.result, tiffRun.stdout, tiffRun.stderr);
    const tiffResult = parseJsonOutput("exiftool sample.tiff", tiffRun.stdout, tiffRun.stderr);
    if (!Array.isArray(tiffResult) || tiffResult.length !== 1) {
      throw new Error(`expected one JSON result for sample.tiff\nstdout:\n${tiffRun.stdout}`);
    }
    const tiffFields = tiffResult[0];
    if (tiffFields.FileType !== "TIFF") {
      throw new Error(`expected TIFF FileType, got ${String(tiffFields.FileType)}`);
    }
    if (tiffFields.ImageSize !== "1x1") {
      throw new Error(`expected TIFF ImageSize=1x1, got ${String(tiffFields.ImageSize)}`);
    }
    console.log("EXIFTOOL_TIFF_OK");

    // ExifTool -json sample.jpg sample.xmp
    const sidecarRun = await runExifTool(perl, exiftoolScript, smokeFiles, ["-json", "/work/sample.jpg", "/work/sample.xmp"]);
    assertRunSuccess("exiftool sample.jpg sample.xmp", sidecarRun.result, sidecarRun.stdout, sidecarRun.stderr);
    const sidecarResult = parseJsonOutput("exiftool sample.jpg sample.xmp", sidecarRun.stdout, sidecarRun.stderr);
    if (!Array.isArray(sidecarResult) || sidecarResult.length !== 2) {
      throw new Error(`expected two JSON results for sample.jpg + sample.xmp\nstdout:\n${sidecarRun.stdout}`);
    }
    const xmpFields = sidecarResult.find((entry) => entry?.SourceFile === "/work/sample.xmp");
    if (!xmpFields) {
      throw new Error(`missing XMP result in multi-file run\nstdout:\n${sidecarRun.stdout}`);
    }
    if (xmpFields.Title !== "zeroperl smoke sample") {
      throw new Error(`expected XMP Title, got ${String(xmpFields.Title)}`);
    }
    if (xmpFields.Description !== "sidecar metadata sample") {
      throw new Error(`expected XMP Description, got ${String(xmpFields.Description)}`);
    }
    console.log("EXIFTOOL_SIDECAR_OK");
  }

  perl.shutdown();
  perl.dispose();
  console.log("WASM_SMOKE_OK");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    process.stderr.write(`${err instanceof Error ? err.message : String(err)}\n`);
    process.exit(1);
  });
