#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
let inputPath = '';
let outputPath = '';
let prefix = '';
let skipRegex = '';

function usage() {
    console.error(`Usage: sfs.js -i <dir> -o <header> [--prefix <prefix>] [--skip <regex>]`);
    process.exit(1);
}

for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '-i' || arg === '--input-path') inputPath = args[++i];
    else if (arg === '-o' || arg === '--output-path') outputPath = args[++i];
    else if (arg === '--prefix') prefix = args[++i];
    else if (arg === '--skip') skipRegex = args[++i];
    else if (arg.startsWith('--')) {
        const [key, val] = arg.slice(2).split('=');
        if (key === 'input-path') inputPath = val;
        else if (key === 'output-path') outputPath = val;
        else if (key === 'prefix') prefix = val;
        else if (key === 'skip') skipRegex = val;
        else usage();
    } else usage();
}

if (!inputPath || !outputPath) usage();

inputPath = path.resolve(inputPath);
if (!fs.existsSync(inputPath) || !fs.statSync(inputPath).isDirectory()) {
    console.error("Input path does not exist or is not a directory");
    process.exit(1);
}

const relpaths = [];
const fileDatas = [];

function traverse(dir) {
    for (const entry of fs.readdirSync(dir)) {
        if (entry.startsWith('.')) continue;
        const fullPath = path.join(dir, entry);
        const stat = fs.statSync(fullPath);
        const rel = path.relative(inputPath, fullPath);
        if (skipRegex && new RegExp(skipRegex).test(rel)) continue;
        if (stat.isDirectory()) traverse(fullPath);
        else if (stat.isFile()) {
            relpaths.push(rel.split(path.sep).join('/'));
            fileDatas.push(fs.readFileSync(fullPath));
        }
    }
}
traverse(inputPath);

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

#define SFS_BUILTIN_PREFIX "${prefix}"

struct sfs_entry {
    const char *abspath;
    const unsigned char *start;
    const unsigned char *end;
};

extern size_t sfs_builtin_files_num;
extern const struct sfs_entry sfs_entries[];

#endif
`;

fs.writeFileSync(outputPath, header);
console.log(`Wrote header: ${outputPath}`);

const binPath = outputPath.replace(/(\.h)?$/, '_data.bin');
fs.writeFileSync(binPath, allData);
console.log(`Wrote binary: ${binPath} (${allData.length} bytes)`);

const entries = relpaths.map((rel, i) => {
    const vpath = prefix ? path.posix.join(prefix, rel) : rel;
    return `    { "${vpath.replace(/"/g, '\\"')}", sfs_builtin_data + ${offsets[i]}, sfs_builtin_data + ${offsets[i]} + ${fileDatas[i].length} },`;
}).join('\n');

const dataC = `#include "${path.basename(outputPath)}"

size_t sfs_builtin_files_num = ${fileDatas.length};

static const unsigned char sfs_builtin_data[] = {
#embed "${binPath}"
};

const struct sfs_entry sfs_entries[] = {
${entries}
};
`;

const dataPath = outputPath.replace(/(\.h)?$/, '_data.c');
fs.writeFileSync(dataPath, dataC);
console.log(`Wrote source: ${dataPath}`);
