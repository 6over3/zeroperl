#ifndef ZEROPERL_SFS_RUNTIME_H
#define ZEROPERL_SFS_RUNTIME_H

#include "sfs_compression.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef FD_MAX_TRACK
#define FD_MAX_TRACK 32
#endif

#ifndef SFS_MAX_OPEN_FILES
#define SFS_MAX_OPEN_FILES 16
#endif

#ifndef SFS_VIRTUAL_FD_BASE
#define SFS_VIRTUAL_FD_BASE 1024
#endif

struct sfs_entry;

typedef struct {
  bool used;
  int fd;
  FILE *fp;
  size_t size;
  SfsLruEntry *lru;
  unsigned char *owned_data;
} SfsOpenFile;

typedef struct {
  bool fd_in_use[FD_MAX_TRACK];
  SfsOpenFile table[SFS_MAX_OPEN_FILES];
  int fd_start;
  int next_virtual_fd;
  const char *prefix;
  SfsCache cache;
} SfsRuntime;

typedef enum { SFS_OK = 0, SFS_ERR = -1, SFS_NOT_OURS = -2 } SFS_Result;

typedef enum {
  SFS_STAT_ERR = -1,
  SFS_STAT_OURS = 0,
  SFS_STAT_NOT_OURS = 1
} SFS_Stat_Result;

void sfs_runtime_init(SfsRuntime *runtime, const char *prefix);
void sfs_runtime_dispose(SfsRuntime *runtime);

void sfs_runtime_mark_fd_in_use(SfsRuntime *runtime, int fd);
void sfs_runtime_mark_fd_free(SfsRuntime *runtime, int fd);
bool sfs_runtime_has_prefix(const SfsRuntime *runtime, const char *path);

int sfs_runtime_open(SfsRuntime *runtime, const struct sfs_entry *entries,
                     size_t entry_count, const char *path, FILE **outfp);
SFS_Result sfs_runtime_close(SfsRuntime *runtime, int fd);
ssize_t sfs_runtime_read(SfsRuntime *runtime, int fd, void *buf, size_t count);
// NOLINTNEXTLINE(bugprone-easily-swappable-parameters): mirrors POSIX lseek signature.
off_t sfs_runtime_lseek(SfsRuntime *runtime, int fd, off_t offset,
                        int whence);
int sfs_runtime_access(SfsRuntime *runtime, const struct sfs_entry *entries,
                       size_t entry_count, const char *path);
SFS_Stat_Result sfs_runtime_stat(SfsRuntime *runtime,
                                 const struct sfs_entry *entries,
                                 size_t entry_count, const char *path, int fd,
                                 struct stat *stbuf);
int sfs_runtime_fileno(SfsRuntime *runtime, FILE *stream);

#endif