#!/usr/bin/env node

import { access, readFile } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { MemoryFileSystem, ZeroPerl } from "@6over3/zeroperl-ts";

const decoder = new TextDecoder();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function decodeChunk(chunk) {
  return typeof chunk === "string" ? chunk : decoder.decode(chunk);
}

function extractIncLines(output) {
  const match = output.match(/__INC_BEGIN__\n([\s\S]*?)__INC_END__/);
  if (!match) {
    throw new Error(`missing @INC markers in output:\n${output}`);
  }

  return match[1]
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function assertEmbeddedInc(incLines) {
  const hasLib = incLines.some((line) =>
    /^\/zeroperl\/lib\/\d+\.\d+\.\d+$/.test(line),
  );
  const hasArch = incLines.some((line) =>
    /^\/zeroperl\/lib\/\d+\.\d+\.\d+\/wasm32-wasi$/.test(line),
  );

  if (!hasLib || !hasArch) {
    throw new Error(
      `embedded @INC paths missing\n${incLines.map((line) => `- ${line}`).join("\n")}`,
    );
  }
}

async function main() {
  const wasmPath = path.resolve(
    process.argv[2] ?? path.join(repoRoot, "output", "zeroperl.wasm"),
  );

  await access(wasmPath, fsConstants.R_OK);
  const wasmBinary = await readFile(wasmPath);

  let stdout = "";
  let stderr = "";

  const perl = await ZeroPerl.create({
    fetch: async () =>
      new Response(wasmBinary, {
        headers: { "content-type": "application/wasm" },
      }),
    fileSystem: new MemoryFileSystem(),
    stdout: (chunk) => {
      stdout += decodeChunk(chunk);
    },
    stderr: (chunk) => {
      stderr += decodeChunk(chunk);
    },
  });

  try {
    const result = await perl.eval(`
      use strict;
      use warnings;
      $| = 1;

      print "__INC_BEGIN__\\n";
      print "$_\\n" for @INC;
      print "__INC_END__\\n";

      require File::Glob;
      require Image::ExifTool;
      require Image::ExifTool::XMP;

      print "__MODULE_OK__\\n";
    `);
    perl.flush();

    if (!result.success) {
      throw new Error(
        [
          `perl eval failed with exit code ${result.exitCode}`,
          result.error ? `eval error: ${result.error}` : "",
          stderr ? `stderr:\n${stderr}` : "",
        ]
          .filter(Boolean)
          .join("\n"),
      );
    }

    const incLines = extractIncLines(stdout);
    assertEmbeddedInc(incLines);

    if (!stdout.includes("__MODULE_OK__")) {
      throw new Error(
        `module load marker missing\nstdout:\n${stdout}\nstderr:\n${stderr}`,
      );
    }

    process.stdout.write(`Embedded @INC verification passed for ${wasmPath}\n`);
  } finally {
    perl.dispose();
  }
}

main().catch((err) => {
  process.stderr.write(`${err instanceof Error ? err.message : String(err)}\n`);
  process.exitCode = 1;
});
