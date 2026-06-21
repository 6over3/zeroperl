#include "sfs_runtime.h"

#if __has_include("zeroperl.h")
#include "zeroperl.h"
#else
struct sfs_entry {
  const char *abspath;
  const unsigned char *start;
  const unsigned char *end;
  uint32_t decompressed_size;
  uint8_t codec;
};
#endif

#include <errno.h>
#include <stdlib.h>
#include <string.h>

static inline bool sfs_runtime_fd_is_in_use(const SfsRuntime *runtime, int fd) {
  if (fd < 0 || fd >= FD_MAX_TRACK) {
    return false;
  }
  return runtime->fd_in_use[fd];
}

static void sfs_runtime_sanitize_path(char *dst, size_t dstsize,
                                      const char *src) {
  size_t j = 0;
  size_t limit = dstsize > 0 ? dstsize - 1 : 0;
  for (size_t i = 0; src[i] != '\0' && j < limit; i++) {
    if (i > 0 && src[i] == '/' && src[i - 1] == '/') {
      continue;
    }
    dst[j++] = src[i];
  }
  if (dstsize > 0) {
    dst[j] = '\0';
  }
}

static const struct sfs_entry *sfs_runtime_lookup_entry(
    const SfsRuntime *runtime, const struct sfs_entry *entries,
    size_t entry_count, const char *path) {
  if (!sfs_runtime_has_prefix(runtime, path)) {
    return NULL;
  }

  size_t path_len = strlen(path);
  char *sanitized = (char *)malloc(path_len + 1);
  if (!sanitized) {
    errno = ENOMEM;
    return NULL;
  }
  sfs_runtime_sanitize_path(sanitized, path_len + 1, path);

  const struct sfs_entry *found = NULL;
  for (size_t i = 0; i < entry_count; i++) {
    if (strcmp(sanitized, entries[i].abspath) == 0) {
      found = &entries[i];
      break;
    }
  }
  free(sanitized);
  return found;
}

static SfsOpenFile *sfs_runtime_find_by_fd(SfsRuntime *runtime, int fd) {
  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (runtime->table[i].used && runtime->table[i].fd == fd) {
      return &runtime->table[i];
    }
  }
  return NULL;
}

static int sfs_runtime_allocate_fd(SfsRuntime *runtime) {
  for (int i = 0; i < SFS_MAX_OPEN_FILES * 2; i++) {
    int fd = runtime->next_virtual_fd++;
    if (fd < SFS_VIRTUAL_FD_BASE) {
      runtime->next_virtual_fd = SFS_VIRTUAL_FD_BASE + 1;
      fd = SFS_VIRTUAL_FD_BASE;
    }
    if (!sfs_runtime_find_by_fd(runtime, fd) &&
        !sfs_runtime_fd_is_in_use(runtime, fd)) {
      sfs_runtime_mark_fd_in_use(runtime, fd);
      return fd;
    }
  }
  errno = EMFILE;
  return -1;
}

void sfs_runtime_init(SfsRuntime *runtime, const char *prefix) {
  memset(runtime, 0, sizeof(*runtime));
  runtime->fd_start = SFS_VIRTUAL_FD_BASE;
  runtime->next_virtual_fd = SFS_VIRTUAL_FD_BASE;
  runtime->prefix = prefix;
  sfs_cache_init(&runtime->cache);
}

void sfs_runtime_dispose(SfsRuntime *runtime) {
  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (runtime->table[i].used && runtime->table[i].fp) {
      fclose(runtime->table[i].fp);
    }
    free(runtime->table[i].owned_data);
    runtime->table[i] = (SfsOpenFile){
        .used = false,
        .fd = 0,
        .fp = NULL,
        .size = 0,
        .lru = NULL,
        .owned_data = NULL,
    };
  }
  sfs_cache_dispose(&runtime->cache);
}

void sfs_runtime_mark_fd_in_use(SfsRuntime *runtime, int fd) {
  if (fd >= 0 && fd < FD_MAX_TRACK) {
    runtime->fd_in_use[fd] = true;
  }
}

void sfs_runtime_mark_fd_free(SfsRuntime *runtime, int fd) {
  if (fd >= 0 && fd < FD_MAX_TRACK) {
    runtime->fd_in_use[fd] = false;
  }
}

bool sfs_runtime_has_prefix(const SfsRuntime *runtime, const char *path) {
  size_t len = strlen(runtime->prefix);
  if (strncmp(path, runtime->prefix, len) == 0) {
    return true;
  }
  return false;
}

int sfs_runtime_open(SfsRuntime *runtime, const struct sfs_entry *entries,
                     size_t entry_count, const char *path, FILE **outfp) {
  errno = 0;
  const struct sfs_entry *entry =
      sfs_runtime_lookup_entry(runtime, entries, entry_count, path);
  if (!entry) {
    if (errno == 0) {
      errno = ENOENT;
    }
    if (outfp) {
      *outfp = NULL;
    }
    return -1;
  }

  const unsigned char *data_start = NULL;
  size_t data_size = 0;
  SfsLruEntry *lru = NULL;
  unsigned char *owned_data = NULL;
  if (sfs_entry_materialize(&runtime->cache, entry, &data_start, &data_size,
                            &lru, &owned_data) != 0) {
    if (outfp) {
      *outfp = NULL;
    }
    return -1;
  }

  FILE *fp = fmemopen((void *)data_start, data_size, "rb");
  if (!fp) {
    free(owned_data);
    sfs_cache_release(lru);
    if (outfp) {
      *outfp = NULL;
    }
    return -1;
  }

  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (!runtime->table[i].used) {
      int fd = sfs_runtime_allocate_fd(runtime);
      if (fd < 0) {
        fclose(fp);
        free(owned_data);
        sfs_cache_release(lru);
        if (outfp) {
          *outfp = NULL;
        }
        return -1;
      }
      runtime->table[i] = (SfsOpenFile){
          .used = true,
          .fd = fd,
          .fp = fp,
          .size = data_size,
          .lru = lru,
          .owned_data = owned_data,
      };
      if (outfp) {
        *outfp = fp;
      }
      return fd;
    }
  }

  fclose(fp);
  free(owned_data);
  sfs_cache_release(lru);
  errno = EMFILE;
  if (outfp) {
    *outfp = NULL;
  }
  return -1;
}

SFS_Result sfs_runtime_close(SfsRuntime *runtime, int fd) {
  SfsOpenFile *entry = sfs_runtime_find_by_fd(runtime, fd);
  if (!entry) {
    return SFS_NOT_OURS;
  }
  if (!entry->fp) {
    return SFS_ERR;
  }

  fclose(entry->fp);
  entry->fp = NULL;
  free(entry->owned_data);
  entry->owned_data = NULL;
  sfs_cache_release(entry->lru);
  entry->lru = NULL;
  sfs_runtime_mark_fd_free(runtime, entry->fd);
  entry->used = false;
  entry->fd = -1;
  entry->size = 0;
  return SFS_OK;
}

ssize_t sfs_runtime_read(SfsRuntime *runtime, int fd, void *buf, size_t count) {
  SfsOpenFile *entry = sfs_runtime_find_by_fd(runtime, fd);
  if (!entry || !entry->fp) {
    return -1;
  }
  return (ssize_t)fread(buf, 1, count, entry->fp);
}

// NOLINTNEXTLINE(bugprone-easily-swappable-parameters): mirrors POSIX lseek signature.
off_t sfs_runtime_lseek(SfsRuntime *runtime, int fd, off_t offset,
            int whence) {
  SfsOpenFile *entry = sfs_runtime_find_by_fd(runtime, fd);
  if (!entry || !entry->fp) {
    return (off_t)-1;
  }
  if (fseek(entry->fp, (long)offset, whence) != 0) {
    return (off_t)-1;
  }
  long pos = ftell(entry->fp);
  return pos < 0 ? (off_t)-1 : (off_t)pos;
}

int sfs_runtime_access(SfsRuntime *runtime, const struct sfs_entry *entries,
                       size_t entry_count, const char *path) {
  errno = 0;
  const struct sfs_entry *entry =
      sfs_runtime_lookup_entry(runtime, entries, entry_count, path);
  if (!entry) {
    if (errno == 0) {
      errno = ENOENT;
    }
    return -1;
  }
  (void)entry;
  return 0;
}

SFS_Stat_Result sfs_runtime_stat(SfsRuntime *runtime,
                                 const struct sfs_entry *entries,
                                 size_t entry_count, const char *path, int fd,
                                 struct stat *stbuf) {
  if (path) {
    if (!sfs_runtime_has_prefix(runtime, path)) {
      return SFS_STAT_NOT_OURS;
    }
    errno = 0;
    const struct sfs_entry *entry =
        sfs_runtime_lookup_entry(runtime, entries, entry_count, path);
    if (!entry) {
      if (errno == 0) {
        errno = ENOENT;
      }
      return SFS_STAT_ERR;
    }
    memset(stbuf, 0, sizeof(*stbuf));
    stbuf->st_size = (off_t)sfs_entry_effective_size(entry);
    stbuf->st_mode = S_IFREG;
    return SFS_STAT_OURS;
  }

  SfsOpenFile *entry = sfs_runtime_find_by_fd(runtime, fd);
  if (!entry) {
    return SFS_STAT_NOT_OURS;
  }
  memset(stbuf, 0, sizeof(*stbuf));
  stbuf->st_size = (off_t)entry->size;
  stbuf->st_mode = S_IFREG;
  return SFS_STAT_OURS;
}

int sfs_runtime_fileno(SfsRuntime *runtime, FILE *stream) {
  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (runtime->table[i].used && runtime->table[i].fp == stream) {
      return runtime->table[i].fd;
    }
  }
  return -1;
}