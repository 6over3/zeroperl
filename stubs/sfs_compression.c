#include "sfs_compression.h"

#include "sfs_lz4.h"
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

static size_t sfs_cache_evict_one(SfsCache *cache);

static int sfs_cache_find_slot(const SfsCache *cache) {
  for (int i = 0; i < SFS_LRU_MAX; i++) {
    if (!cache->entries[i].abspath) {
      return i;
    }
  }
  return -1;
}

static SfsLruEntry *sfs_cache_lookup(SfsCache *cache, const char *abspath) {
  // Cache keys are canonicalized absolute paths; string equality is required
  // because callers may provide distinct pointers with identical content.
  for (int i = 0; i < SFS_LRU_MAX; i++) {
    if (cache->entries[i].abspath &&
        strcmp(cache->entries[i].abspath, abspath) == 0) {
      return &cache->entries[i];
    }
  }
  return NULL;
}

static bool sfs_cache_prepare_slot(SfsCache *cache, size_t decomp_size,
                                   int *slot) {
  // If the entry cannot fit under the byte cap or all candidates are pinned,
  // caller will fall back to transient (non-cached) ownership.
  if (decomp_size > SFS_LRU_CAP_BYTES) {
    return false;
  }

  while (cache->bytes + decomp_size > SFS_LRU_CAP_BYTES) {
    if (sfs_cache_evict_one(cache) == 0) {
      return false;
    }
  }

  *slot = sfs_cache_find_slot(cache);
  while (*slot < 0) {
    if (sfs_cache_evict_one(cache) == 0) {
      return false;
    }
    *slot = sfs_cache_find_slot(cache);
  }

  return true;
}

static int sfs_decompress_alloc(const struct sfs_entry *entry,
                                unsigned char **out_buf,
                                size_t *out_size) {
  size_t comp_size = (size_t)(entry->end - entry->start);
  size_t decomp_size = (size_t)entry->decompressed_size;

  unsigned char *buf = (unsigned char *)malloc(decomp_size);
  if (!buf) {
    errno = ENOMEM;
    return -1;
  }

  if (sfs_lz4_decompress_frame(entry->start, comp_size, buf, decomp_size) != 0) {
    free(buf);
    return -1;
  }

  *out_buf = buf;
  *out_size = decomp_size;
  return 0;
}

static size_t sfs_cache_evict_one(SfsCache *cache) {
  uint64_t oldest = UINT64_MAX;
  int victim = -1;
  for (int i = 0; i < SFS_LRU_MAX; i++) {
    if (cache->entries[i].abspath && cache->entries[i].refcount == 0) {
      if (cache->entries[i].lru_tick < oldest) {
        oldest = cache->entries[i].lru_tick;
        victim = i;
      }
    }
  }
  if (victim < 0) {
    return 0;
  }
  size_t freed = cache->entries[victim].size;
  free(cache->entries[victim].data);
  cache->entries[victim] = (SfsLruEntry){0};
  cache->bytes -= freed;
  return freed;
}

void sfs_cache_init(SfsCache *cache) {
  memset(cache, 0, sizeof(*cache));
}

void sfs_cache_dispose(SfsCache *cache) {
  for (int i = 0; i < SFS_LRU_MAX; i++) {
    free(cache->entries[i].data);
    cache->entries[i] = (SfsLruEntry){0};
  }
  cache->bytes = 0;
  cache->clock = 0;
}

size_t sfs_entry_effective_size(const struct sfs_entry *entry) {
  if (entry->codec == 1) {
    return (size_t)entry->decompressed_size;
  }
  return (size_t)(entry->end - entry->start);
}

int sfs_entry_materialize(SfsCache *cache, const struct sfs_entry *entry,
                          const unsigned char **data_start,
                          size_t *data_size,
                          SfsLruEntry **cache_handle,
                          unsigned char **owned_data) {
  if (cache_handle) {
    *cache_handle = NULL;
  }
  if (owned_data) {
    *owned_data = NULL;
  }

  if (entry->codec != 1) {
    *data_start = entry->start;
    *data_size = (size_t)(entry->end - entry->start);
    return 0;
  }

  SfsLruEntry *cached = sfs_cache_lookup(cache, entry->abspath);
  if (cached) {
    cached->lru_tick = ++cache->clock;
    cached->refcount++;
    *data_start = cached->data;
    *data_size = cached->size;
    if (cache_handle) {
      *cache_handle = cached;
    }
    return 0;
  }

  size_t decomp_size = (size_t)entry->decompressed_size;
  int slot = -1;
  bool can_cache = sfs_cache_prepare_slot(cache, decomp_size, &slot);

  unsigned char *buf = NULL;
  size_t out_size = 0;
  if (sfs_decompress_alloc(entry, &buf, &out_size) != 0) {
    return -1;
  }

  if (!can_cache) {
    *data_start = buf;
    *data_size = out_size;
    if (owned_data) {
      *owned_data = buf;
    }
    return 0;
  }

  cache->entries[slot] = (SfsLruEntry){
      .abspath = entry->abspath,
      .data = buf,
      .size = out_size,
      .refcount = 1,
      .lru_tick = ++cache->clock,
  };
  cache->bytes += out_size;

  *data_start = cache->entries[slot].data;
  *data_size = cache->entries[slot].size;
  if (cache_handle) {
    *cache_handle = &cache->entries[slot];
  }
  return 0;
}

void sfs_cache_release(SfsLruEntry *entry) {
  if (entry && entry->refcount > 0) {
    entry->refcount--;
  }
}