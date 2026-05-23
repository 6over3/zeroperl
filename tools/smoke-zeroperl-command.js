#!/usr/bin/env node

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { WASI } = require("node:wasi");

async function main() {
  const wasmPath = process.argv[2] || "output/zeroperl_command.wasm";
  const bytes = fs.readFileSync(wasmPath);
  const mod = await WebAssembly.compile(bytes);

  const imports = WebAssembly.Module.imports(mod);
  const envImports = imports.filter((entry) => entry.module === "env");
  if (envImports.length > 0) {
    const names = envImports.map((entry) => entry.name).join(", ");
    throw new Error(`Unexpected env imports in default command build: ${names}`);
  }

  const exports = new Set(WebAssembly.Module.exports(mod).map((entry) => entry.name));
  if (!exports.has("_start")) {
    throw new Error("zeroperl_command.wasm does not export _start");
  }

  const preopenRoot = fs.mkdtempSync(path.join(os.tmpdir(), "zeroperl-wasi-"));
  fs.mkdirSync(path.join(preopenRoot, "dev"), { recursive: true });
  fs.writeFileSync(path.join(preopenRoot, "dev", "null"), "");

  try {
    const wasi = new WASI({
      version: "preview1",
      args: [wasmPath, "-e", "print qq(zeroperl command smoke ok\\n);"],
      env: { LANG: "C", LC_ALL: "C" },
      preopens: { "/": preopenRoot },
    });

    const instance = await WebAssembly.instantiate(mod, {
      wasi_snapshot_preview1: wasi.wasiImport,
    });

    if (typeof instance.exports._start !== "function") {
      throw new Error("instance.exports._start is not callable");
    }

    if (typeof wasi.finalizeBindings === "function") {
      wasi.finalizeBindings(instance);
      if (typeof instance.exports._initialize === "function") {
        instance.exports._initialize();
      }
      instance.exports._start();
    } else if (typeof instance.exports._initialize === "function") {
      throw new Error(
        "Node WASI.finalizeBindings is required to smoke-test a returnable _start export that also exports _initialize",
      );
    } else {
      wasi.start(instance);
    }

    if (typeof instance.exports.asyncify_get_state === "function") {
      const state = instance.exports.asyncify_get_state();
      if (state !== 0) {
        throw new Error(`Invalid async state ${state}, expected 0`);
      }
    }
  } finally {
    fs.rmSync(preopenRoot, { recursive: true, force: true });
  }

  console.log("zeroperl_command.wasm smoke test passed");
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
