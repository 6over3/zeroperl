#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const lz4 = require("lz4");

function usage() {
  console.error(
    `Usage: sfs.js -o <header> [--prefix <prefix>] [--skip <regex>] [--compress] [--empty]`,
  );
  console.error(
    `       sfs.js -i <dir> -o <header> [--prefix <prefix>] [--skip <regex>] [--compress]`,
  );
  process.exit(1);
}

function parseArgs(args) {
  let inputPath = "";
  let outputPath = "";
  let prefix = "";
  let skipRegex = "";
  let compress = false;
  let empty = false;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "-i" || arg === "--input-path") inputPath = args[++i];
    else if (arg === "-o" || arg === "--output-path") outputPath = args[++i];
    else if (arg === "--prefix") prefix = args[++i];
    else if (arg === "--skip") skipRegex = args[++i];
    else if (arg === "--compress") compress = true;
    else if (arg === "--empty") empty = true;
    else if (arg.startsWith("--")) {
      const [key, val] = arg.slice(2).split("=");
      if (key === "input-path") inputPath = val;
      else if (key === "output-path") outputPath = val;
      else if (key === "prefix") prefix = val;
      else if (key === "skip") skipRegex = val;
      else if (key === "compress") {
        compress = true;
      } else if (key === "empty") {
        empty = true;
      } else usage();
    } else {
      usage();
    }
  }

  if (!outputPath) usage();

  if (!empty) {
    if (!inputPath) usage();
    inputPath = path.resolve(inputPath);
    if (!fs.existsSync(inputPath) || !fs.statSync(inputPath).isDirectory()) {
      console.error("Input path does not exist or is not a directory");
      process.exit(1);
    }
  }

  return { inputPath, outputPath, prefix, skipRegex, compress, empty };
}

function collectInputFiles(inputPath, skipRegex) {
  const relpaths = [];
  const rawDatas = [];
  const skipPattern = skipRegex ? new RegExp(skipRegex) : null;

  function traverse(dir) {
    for (const entry of fs.readdirSync(dir).sort()) {
      if (entry.startsWith(".")) continue;
      const fullPath = path.join(dir, entry);
      const stat = fs.statSync(fullPath);
      const rel = path.relative(inputPath, fullPath);
      if (skipPattern && skipPattern.test(rel)) continue;
      if (stat.isDirectory()) {
        traverse(fullPath);
      } else if (stat.isFile()) {
        relpaths.push(rel.split(path.sep).join("/"));
        rawDatas.push(fs.readFileSync(fullPath));
      }
    }
  }

  traverse(inputPath);
  return { relpaths, rawDatas };
}

function compressLz4Frame(raw) {
  return lz4.encode(raw);
}

function buildFileData(rawDatas, compress) {
  const fileDatas = [];
  const decompressedSizes = [];
  const codecs = [];

  if (compress) {
    for (const raw of rawDatas) {
      const compBuf = compressLz4Frame(raw);
      fileDatas.push(compBuf);
      decompressedSizes.push(raw.length);
      codecs.push(1);
    }
  } else {
    for (const raw of rawDatas) {
      fileDatas.push(raw);
      decompressedSizes.push(0);
      codecs.push(0);
    }
  }

  return { fileDatas, decompressedSizes, codecs };
}

function buildOutputArtifacts(
  relpaths,
  fileDatas,
  decompressedSizes,
  codecs,
  prefix,
  outputPath,
) {
  const offsets = [];
  let totalSize = 0;
  for (const data of fileDatas) {
    offsets.push(totalSize);
    totalSize += data.length;
  }

  const allData = Buffer.concat(fileDatas, totalSize);

  const header = `#ifndef SFS_H
#define SFS_H

#include <stddef.h>
#include <stdint.h>

#define SFS_BUILTIN_PREFIX "${prefix}"

struct sfs_entry {
    const char *abspath;
    const unsigned char *start;
    const unsigned char *end;
    uint32_t decompressed_size;
    uint8_t codec;
};

extern size_t sfs_builtin_files_num;
extern const struct sfs_entry sfs_entries[];

#endif
`;

  const binPath = outputPath.replace(/(\.h)?$/, "_data.bin");
  const entries = relpaths
    .map((rel, i) => {
      const vpath = prefix ? path.posix.join(prefix, rel) : rel;
      return `    { "${vpath.replace(/"/g, '\\"')}", sfs_builtin_data + ${offsets[i]}, sfs_builtin_data + ${offsets[i]} + ${fileDatas[i].length}, ${decompressedSizes[i]}, ${codecs[i]} },`;
    })
    .join("\n");

  const dataC = `#include "${path.basename(outputPath)}"

size_t sfs_builtin_files_num = ${fileDatas.length};

static const unsigned char sfs_builtin_data[] = {
#embed "${binPath}"
};

const struct sfs_entry sfs_entries[] = {
${entries}
};
`;

  return {
    header,
    binPath,
    allData,
    dataC,
    dataPath: outputPath.replace(/(\.h)?$/, "_data.c"),
  };
}

function writeArtifacts(outputPath, artifacts) {
  fs.writeFileSync(outputPath, artifacts.header);
  console.log(`Wrote header: ${outputPath}`);

  fs.writeFileSync(artifacts.binPath, artifacts.allData);
  console.log(
    `Wrote binary: ${artifacts.binPath} (${artifacts.allData.length} bytes)`,
  );

  fs.writeFileSync(artifacts.dataPath, artifacts.dataC);
  console.log(`Wrote source: ${artifacts.dataPath}`);
}

function generateSfs(options) {
  if (options.empty) {
    const artifacts = buildOutputArtifacts(
      [],
      [],
      [],
      [],
      options.prefix,
      options.outputPath,
    );
    writeArtifacts(options.outputPath, artifacts);
    return artifacts;
  }
  const { relpaths, rawDatas } = collectInputFiles(
    options.inputPath,
    options.skipRegex,
  );
  const { fileDatas, decompressedSizes, codecs } = buildFileData(
    rawDatas,
    options.compress,
  );
  const artifacts = buildOutputArtifacts(
    relpaths,
    fileDatas,
    decompressedSizes,
    codecs,
    options.prefix,
    options.outputPath,
  );
  writeArtifacts(options.outputPath, artifacts);
  return artifacts;
}

function main(argv) {
  generateSfs(parseArgs(argv));
}

if (require.main === module) {
  main(process.argv.slice(2));
}

module.exports = {
  buildFileData,
  collectInputFiles,
  compressLz4Frame,
  generateSfs,
  parseArgs,
};
