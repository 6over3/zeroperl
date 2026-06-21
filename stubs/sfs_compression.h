#ifndef ZEROPERL_SFS_COMPRESSION_H
#define ZEROPERL_SFS_COMPRESSION_H

#include <stddef.h>
#include <stdint.h>

struct sfs_entry;

typedef struct SfsLruEntry {
  const char *abspath;
  unsigned char *data;
  size_t size;
  int refcount;
  uint64_t lru_tick;
} SfsLruEntry;

#ifndef SFS_LRU_MAX
#define SFS_LRU_MAX  4096
#endif

#ifndef SFS_LRU_CAP_BYTES
#define SFS_LRU_CAP_BYTES ((size_t)20u * 1024u * 1024u)
#endif

typedef struct SfsCache {
  SfsLruEntry entries[SFS_LRU_MAX];
  size_t bytes;
  uint64_t clock;
} SfsCache;

void sfs_cache_init(SfsCache *cache);
void sfs_cache_dispose(SfsCache *cache);

int sfs_entry_materialize(SfsCache *cache, const struct sfs_entry *entry,
                          const unsigned char **data_start,
                          size_t *data_size,
                          SfsLruEntry **cache_handle,
                          unsigned char **owned_data);

void sfs_cache_release(SfsLruEntry *entry);

size_t sfs_entry_effective_size(const struct sfs_entry *entry);

#endif