/*
 * tests/sfs/test-sfs.c
 * Unit tests for production SFS runtime and compression modules.
 */

#include <errno.h>
#include <fcntl.h>
#include <lz4frame.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/*
 * Local mirror of the sfs_entry struct defined in the generated header.
 * We keep our own copy so the test harness does not depend on a specific
 * zeroperl.h generation (the struct layout is stable).
 */
struct sfs_entry {
  const char *abspath;
  const unsigned char *start;
  const unsigned char *end;
  uint32_t decompressed_size;
  uint8_t codec;
};

#ifndef SFS_LRU_MAX
#define SFS_LRU_MAX 8
#endif

#ifndef SFS_LRU_CAP_BYTES
#define SFS_LRU_CAP_BYTES 256
#endif

#include "../../stubs/sfs_runtime.h"

static int g_passed = 0;
static int g_failed = 0;

static void t_ok(int cond, const char *msg) {
  if (cond) {
    printf("  PASS: %s\n", msg);
    g_passed++;
  } else {
    printf("  FAIL: %s\n", msg);
    g_failed++;
  }
}

#define T_OK(cond) t_ok((cond), #cond)
#define T_EQ(a, b) t_ok((a) == (b), #a " == " #b)
#define T_STR_EQ(a, b) t_ok(strcmp((a), (b)) == 0, #a " == " #b)

static unsigned char *compress_frame(const unsigned char *src, size_t src_len,
                                     size_t *out_len) {
  size_t cap = LZ4F_compressFrameBound(src_len, NULL);
  unsigned char *buf = (unsigned char *)malloc(cap);
  if (!buf) {
    return NULL;
  }
  size_t written = LZ4F_compressFrame(buf, cap, src, src_len, NULL);
  if (LZ4F_isError(written)) {
    free(buf);
    errno = EIO;
    return NULL;
  }
  *out_len = written;
  return buf;
}

static bool cache_has_path(const SfsCache *cache, const char *path) {
  for (int i = 0; i < SFS_LRU_MAX; i++) {
    if (cache->entries[i].abspath && strcmp(cache->entries[i].abspath, path) == 0) {
      return true;
    }
  }
  return false;
}

static void test_access_found_and_missing(void) {
  printf("\n--- access ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw[] = "package Carp; 1;\n";
  struct sfs_entry entries[] = {{
      .abspath = "/zeroperl/lib/Carp.pm",
      .start = raw,
      .end = raw + sizeof(raw) - 1,
      .decompressed_size = 0,
      .codec = 0,
  }};

  errno = 0;
  T_EQ(sfs_runtime_access(&runtime, entries, 1, "/zeroperl/lib/Carp.pm"), 0);
  errno = 0;
  T_EQ(sfs_runtime_access(&runtime, entries, 1, "/zeroperl//lib/Carp.pm"), 0);
  errno = 0;
  T_EQ(sfs_runtime_access(&runtime, entries, 1, "/zeroperl/lib/Missing.pm"), -1);
  T_EQ(errno, ENOENT);

  sfs_runtime_dispose(&runtime);
}

static void test_open_read_close_uncompressed(void) {
  printf("\n--- open/read/close uncompressed ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw[] = "package Carp; 1;\n";
  struct sfs_entry entries[] = {{
      .abspath = "/zeroperl/lib/Carp.pm",
      .start = raw,
      .end = raw + sizeof(raw) - 1,
      .decompressed_size = 0,
      .codec = 0,
  }};

  FILE *fp = NULL;
  int fd = sfs_runtime_open(&runtime, entries, 1, "/zeroperl/lib/Carp.pm", &fp);
  T_OK(fd >= 0);
  T_OK(fp != NULL);
  T_EQ(sfs_runtime_fileno(&runtime, fp), fd);

  char buf[64] = {0};
  ssize_t n = sfs_runtime_read(&runtime, fd, buf, 7);
  T_EQ(n, 7);
  T_OK(memcmp(buf, raw, 7) == 0);

  T_EQ(sfs_runtime_lseek(&runtime, fd, -2, SEEK_END), (off_t)(sizeof(raw) - 3));
  memset(buf, 0, sizeof(buf));
  n = sfs_runtime_read(&runtime, fd, buf, 8);
  T_EQ(n, 2);
  T_OK(memcmp(buf, raw + (sizeof(raw) - 3), 2) == 0);
  T_EQ(sfs_runtime_read(&runtime, fd, buf, 8), 0);

  T_EQ(sfs_runtime_lseek(&runtime, fd, 0, SEEK_SET), 0);
  memset(buf, 0, sizeof(buf));
  n = sfs_runtime_read(&runtime, fd, buf, sizeof(buf) - 1);
  T_EQ((size_t)n, sizeof(raw) - 1);
  T_STR_EQ(buf, (const char *)raw);

  T_EQ(sfs_runtime_close(&runtime, fd), SFS_OK);
  T_EQ(sfs_runtime_close(&runtime, fd), SFS_NOT_OURS);

  sfs_runtime_dispose(&runtime);
}

static void test_virtual_fd_namespace_avoids_low_fds(void) {
  printf("\n--- virtual fd namespace avoids low fds ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw[] = "package Carp; 1;\n";
  struct sfs_entry entries[] = {{
      .abspath = "/zeroperl/lib/Carp.pm",
      .start = raw,
      .end = raw + sizeof(raw) - 1,
      .decompressed_size = 0,
      .codec = 0,
  }};

  FILE *fp = NULL;
  int fd = sfs_runtime_open(&runtime, entries, 1, "/zeroperl/lib/Carp.pm", &fp);
  T_OK(fd >= SFS_VIRTUAL_FD_BASE);
  T_EQ(sfs_runtime_fileno(&runtime, fp), fd);
  T_EQ(sfs_runtime_close(&runtime, fd), SFS_OK);

  sfs_runtime_dispose(&runtime);
}

static void test_open_read_stat_compressed(void) {
  printf("\n--- open/read/stat compressed ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw[] = "package Image::ExifTool; 1;\n";
  size_t comp_len = 0;
  unsigned char *comp = compress_frame(raw, sizeof(raw) - 1, &comp_len);
  T_OK(comp != NULL);
  if (!comp) {
    sfs_runtime_dispose(&runtime);
    return;
  }

  struct sfs_entry entries[] = {{
      .abspath = "/zeroperl/lib/site_perl/Image/ExifTool.pm",
      .start = comp,
      .end = comp + comp_len,
      .decompressed_size = sizeof(raw) - 1,
      .codec = 1,
  }};

  struct stat st;
  T_EQ(sfs_runtime_stat(&runtime, entries, 1,
                        "/zeroperl/lib/site_perl/Image/ExifTool.pm", -1, &st),
       SFS_STAT_OURS);
  T_EQ((size_t)st.st_size, sizeof(raw) - 1);
  T_EQ((st.st_mode & S_IFMT), S_IFREG);
  memset(&st, 0, sizeof(st));
  T_EQ(sfs_runtime_stat(&runtime, entries, 1,
            "/zeroperl//lib/site_perl/Image/ExifTool.pm", -1,
            &st),
    SFS_STAT_OURS);
  T_EQ((size_t)st.st_size, sizeof(raw) - 1);
  T_EQ((st.st_mode & S_IFMT), S_IFREG);

  FILE *fp = NULL;
  int fd = sfs_runtime_open(&runtime, entries, 1,
             "/zeroperl//lib/site_perl/Image/ExifTool.pm", &fp);
  T_OK(fd >= 0);

  char buf[64] = {0};
  ssize_t n = sfs_runtime_read(&runtime, fd, buf, sizeof(buf) - 1);
  T_EQ((size_t)n, sizeof(raw) - 1);
  T_STR_EQ(buf, (const char *)raw);

  memset(&st, 0, sizeof(st));
  T_EQ(sfs_runtime_stat(&runtime, entries, 1, NULL, fd, &st), SFS_STAT_OURS);
  T_EQ((size_t)st.st_size, sizeof(raw) - 1);
  T_EQ((st.st_mode & S_IFMT), S_IFREG);

  T_EQ(sfs_runtime_close(&runtime, fd), SFS_OK);

  free(comp);
  sfs_runtime_dispose(&runtime);
}

static void test_bad_compressed_open_fails(void) {
  printf("\n--- bad compressed open fails ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char bad[] = {0x00, 0x01, 0x02, 0x03};
  struct sfs_entry entries[] = {{
      .abspath = "/zeroperl/lib/Bad.pm",
      .start = bad,
      .end = bad + sizeof(bad),
      .decompressed_size = 32,
      .codec = 1,
  }};

  errno = 0;
  T_EQ(sfs_runtime_open(&runtime, entries, 1, "/zeroperl/lib/Bad.pm", NULL), -1);
  T_EQ(errno, EIO);

  sfs_runtime_dispose(&runtime);
}

static void test_lseek_and_emfile(void) {
  printf("\n--- lseek and emfile ---\n");
  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw[] = "#!/usr/bin/perl\n";
  struct sfs_entry entry = {
      .abspath = "/zeroperl/run.pl",
      .start = raw,
      .end = raw + sizeof(raw) - 1,
      .decompressed_size = 0,
      .codec = 0,
  };

  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    FILE *fp = NULL;
    int fd = sfs_runtime_open(&runtime, &entry, 1, "/zeroperl/run.pl", &fp);
    T_OK(fd >= 0);
  }

  errno = 0;
  T_EQ(sfs_runtime_open(&runtime, &entry, 1, "/zeroperl/run.pl", NULL), -1);
  T_EQ(errno, EMFILE);

  sfs_runtime_dispose(&runtime);

  sfs_runtime_init(&runtime, "/zeroperl");
  FILE *fp = NULL;
  int fd = sfs_runtime_open(&runtime, &entry, 1, "/zeroperl/run.pl", &fp);
  T_OK(fd >= 0);
  T_EQ(sfs_runtime_lseek(&runtime, fd, 0, SEEK_END), (off_t)(sizeof(raw) - 1));
  T_EQ(sfs_runtime_lseek(&runtime, fd, 0, SEEK_SET), 0);
  T_EQ(sfs_runtime_lseek(&runtime, fd, 4, SEEK_SET), 4);
  T_EQ(sfs_runtime_lseek(&runtime, fd, 3, SEEK_CUR), 7);
  T_EQ(sfs_runtime_close(&runtime, fd), SFS_OK);
  sfs_runtime_dispose(&runtime);
}

static void test_cache_key_uses_string_equality(void) {
  printf("\n--- cache key uses string equality ---\n");

  static const unsigned char raw[] = "package Cache::Key; 1;\n";
  size_t comp_len = 0;
  unsigned char *comp = compress_frame(raw, sizeof(raw) - 1, &comp_len);
  T_OK(comp != NULL);
  if (!comp) {
    return;
  }

  char *p1 = strdup("/zeroperl/lib/Cache/Key.pm");
  char *p2 = strdup("/zeroperl/lib/Cache/Key.pm");
  T_OK(p1 != NULL && p2 != NULL);
  if (!p1 || !p2) {
    free(p1);
    free(p2);
    free(comp);
    return;
  }

  struct sfs_entry e1 = {
      .abspath = p1,
      .start = comp,
      .end = comp + comp_len,
      .decompressed_size = sizeof(raw) - 1,
      .codec = 1,
  };
  struct sfs_entry e2 = {
      .abspath = p2,
      .start = comp,
      .end = comp + comp_len,
      .decompressed_size = sizeof(raw) - 1,
      .codec = 1,
  };

  SfsCache cache;
  sfs_cache_init(&cache);

  const unsigned char *d1 = NULL;
  size_t n1 = 0;
  SfsLruEntry *h1 = NULL;
  unsigned char *owned1 = NULL;
  T_EQ(sfs_entry_materialize(&cache, &e1, &d1, &n1, &h1, &owned1), 0);
  T_OK(h1 != NULL);
  T_OK(owned1 == NULL);

  const unsigned char *d2 = NULL;
  size_t n2 = 0;
  SfsLruEntry *h2 = NULL;
  unsigned char *owned2 = NULL;
  T_EQ(sfs_entry_materialize(&cache, &e2, &d2, &n2, &h2, &owned2), 0);
  T_OK(h2 != NULL);
  T_OK(owned2 == NULL);
  T_OK(h1 == h2);
  T_OK(d1 == d2);

  sfs_cache_release(h2);
  sfs_cache_release(h1);
  sfs_cache_dispose(&cache);
  free(p1);
  free(p2);
  free(comp);
}

static void test_cache_saturation_degrades_without_failure(void) {
  printf("\n--- cache saturation degrades without failure ---\n");

  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  struct sfs_entry entries[SFS_LRU_MAX + 1];
  unsigned char *comp_bufs[SFS_LRU_MAX + 1] = {0};
  int fds[SFS_LRU_MAX + 1];
  memset(fds, -1, sizeof(fds));

  char raw[64];
  for (int i = 0; i < SFS_LRU_MAX + 1; i++) {
    int n = snprintf(raw, sizeof(raw), "package P%04d; 1;\n", i);
    size_t comp_len = 0;
    comp_bufs[i] = compress_frame((const unsigned char *)raw, (size_t)n, &comp_len);
    T_OK(comp_bufs[i] != NULL);
    if (!comp_bufs[i]) {
      continue;
    }

    char *path = (char *)malloc(64);
    T_OK(path != NULL);
    if (!path) {
      continue;
    }
    snprintf(path, 64, "/zeroperl/lib/P%04d.pm", i);

    entries[i] = (struct sfs_entry){
        .abspath = path,
        .start = comp_bufs[i],
        .end = comp_bufs[i] + comp_len,
        .decompressed_size = (uint32_t)n,
        .codec = 1,
    };
  }

  for (int i = 0; i < SFS_LRU_MAX; i++) {
    FILE *fp = NULL;
    fds[i] = sfs_runtime_open(&runtime, entries, SFS_LRU_MAX + 1, entries[i].abspath,
                              &fp);
    T_OK(fds[i] >= 0);
    T_OK(fp != NULL);
  }

  size_t bytes_before = runtime.cache.bytes;
  FILE *last_fp = NULL;
  fds[SFS_LRU_MAX] = sfs_runtime_open(&runtime, entries, SFS_LRU_MAX + 1,
                                      entries[SFS_LRU_MAX].abspath, &last_fp);
  T_OK(fds[SFS_LRU_MAX] >= 0);
  T_OK(last_fp != NULL);

  SfsOpenFile *sat_slot = NULL;
  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (runtime.table[i].used && runtime.table[i].fd == fds[SFS_LRU_MAX]) {
      sat_slot = &runtime.table[i];
      break;
    }
  }
  T_OK(sat_slot != NULL);
  if (sat_slot) {
    T_OK(sat_slot->lru == NULL);
    T_OK(sat_slot->owned_data != NULL);
  }
  T_OK(runtime.cache.bytes <= SFS_LRU_CAP_BYTES);
  T_EQ(runtime.cache.bytes, bytes_before);

  for (int i = 0; i < SFS_LRU_MAX + 1; i++) {
    if (fds[i] >= 0) {
      T_EQ(sfs_runtime_close(&runtime, fds[i]), SFS_OK);
    }
  }

  for (int i = 0; i < SFS_LRU_MAX + 1; i++) {
    free((void *)entries[i].abspath);
    free(comp_bufs[i]);
  }
  sfs_runtime_dispose(&runtime);
}

static void test_cache_cap_soft_when_entries_pinned(void) {
  printf("\n--- cache cap soft with pinned entries ---\n");

  SfsRuntime runtime;
  sfs_runtime_init(&runtime, "/zeroperl");

  static const unsigned char raw1[] =
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
  static const unsigned char raw2[] =
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

  size_t comp1_len = 0;
  size_t comp2_len = 0;
  unsigned char *comp1 = compress_frame(raw1, sizeof(raw1) - 1, &comp1_len);
  unsigned char *comp2 = compress_frame(raw2, sizeof(raw2) - 1, &comp2_len);
  T_OK(comp1 != NULL);
  T_OK(comp2 != NULL);
  if (!comp1 || !comp2) {
    free(comp1);
    free(comp2);
    sfs_runtime_dispose(&runtime);
    return;
  }

  struct sfs_entry entries[] = {
      {
          .abspath = "/zeroperl/lib/CapOne.pm",
          .start = comp1,
          .end = comp1 + comp1_len,
          .decompressed_size = sizeof(raw1) - 1,
          .codec = 1,
      },
      {
          .abspath = "/zeroperl/lib/CapTwo.pm",
          .start = comp2,
          .end = comp2 + comp2_len,
          .decompressed_size = sizeof(raw2) - 1,
          .codec = 1,
      },
  };

  FILE *fp1 = NULL;
  int fd1 = sfs_runtime_open(&runtime, entries, 2, entries[0].abspath, &fp1);
  T_OK(fd1 >= 0);
  T_OK(fp1 != NULL);

  size_t bytes_after_first = runtime.cache.bytes;
  T_OK(bytes_after_first <= SFS_LRU_CAP_BYTES);

  FILE *fp2 = NULL;
  int fd2 = sfs_runtime_open(&runtime, entries, 2, entries[1].abspath, &fp2);
  T_OK(fd2 >= 0);
  T_OK(fp2 != NULL);
  T_OK(runtime.cache.bytes <= SFS_LRU_CAP_BYTES);

  SfsOpenFile *slot2 = NULL;
  for (int i = 0; i < SFS_MAX_OPEN_FILES; i++) {
    if (runtime.table[i].used && runtime.table[i].fd == fd2) {
      slot2 = &runtime.table[i];
      break;
    }
  }
  T_OK(slot2 != NULL);
  if (slot2) {
    T_OK(slot2->lru == NULL);
    T_OK(slot2->owned_data != NULL);
  }

  T_EQ(sfs_runtime_close(&runtime, fd2), SFS_OK);
  T_EQ(sfs_runtime_close(&runtime, fd1), SFS_OK);

  free(comp1);
  free(comp2);
  sfs_runtime_dispose(&runtime);
}

static void test_cache_evicts_oldest_unref_entry_under_cap(void) {
  printf("\n--- cache evicts oldest unreferenced entry under cap ---\n");

  static const unsigned char raw1[] =
      "111111111111111111111111111111111111111111111111111111111111111111111111"
      "111111111111111111111111111111111111111111111111";
  static const unsigned char raw2[] =
      "222222222222222222222222222222222222222222222222222222222222222222222222"
      "222222222222222222222222222222222222222222222222";
  static const unsigned char raw3[] =
      "333333333333333333333333333333333333333333333333333333333333333333333333"
      "333333333333333333333333333333333333333333333333";

  size_t c1_len = 0;
  size_t c2_len = 0;
  size_t c3_len = 0;
  unsigned char *c1 = compress_frame(raw1, sizeof(raw1) - 1, &c1_len);
  unsigned char *c2 = compress_frame(raw2, sizeof(raw2) - 1, &c2_len);
  unsigned char *c3 = compress_frame(raw3, sizeof(raw3) - 1, &c3_len);
  T_OK(c1 != NULL);
  T_OK(c2 != NULL);
  T_OK(c3 != NULL);
  if (!c1 || !c2 || !c3) {
    free(c1);
    free(c2);
    free(c3);
    return;
  }

  struct sfs_entry e1 = {
      .abspath = "/zeroperl/lib/EvictOne.pm",
      .start = c1,
      .end = c1 + c1_len,
      .decompressed_size = sizeof(raw1) - 1,
      .codec = 1,
  };
  struct sfs_entry e2 = {
      .abspath = "/zeroperl/lib/EvictTwo.pm",
      .start = c2,
      .end = c2 + c2_len,
      .decompressed_size = sizeof(raw2) - 1,
      .codec = 1,
  };
  struct sfs_entry e3 = {
      .abspath = "/zeroperl/lib/EvictThree.pm",
      .start = c3,
      .end = c3 + c3_len,
      .decompressed_size = sizeof(raw3) - 1,
      .codec = 1,
  };

  SfsCache cache;
  sfs_cache_init(&cache);

  const unsigned char *d = NULL;
  size_t n = 0;
  SfsLruEntry *h = NULL;
  unsigned char *owned = NULL;

  T_EQ(sfs_entry_materialize(&cache, &e1, &d, &n, &h, &owned), 0);
  T_OK(h != NULL);
  T_OK(owned == NULL);
  sfs_cache_release(h);

  h = NULL;
  T_EQ(sfs_entry_materialize(&cache, &e2, &d, &n, &h, &owned), 0);
  T_OK(h != NULL);
  T_OK(owned == NULL);
  sfs_cache_release(h);

  T_OK(cache_has_path(&cache, e1.abspath));
  T_OK(cache_has_path(&cache, e2.abspath));
  T_OK(cache.bytes <= SFS_LRU_CAP_BYTES);

  h = NULL;
  T_EQ(sfs_entry_materialize(&cache, &e3, &d, &n, &h, &owned), 0);
  T_OK(h != NULL);
  T_OK(owned == NULL);
  sfs_cache_release(h);

  T_OK(!cache_has_path(&cache, e1.abspath));
  T_OK(cache_has_path(&cache, e2.abspath));
  T_OK(cache_has_path(&cache, e3.abspath));
  T_OK(cache.bytes <= SFS_LRU_CAP_BYTES);

  sfs_cache_dispose(&cache);
  free(c1);
  free(c2);
  free(c3);
}

static void test_system_open_nonexistent_propagates_enoent(void) {
  printf("\n--- system open nonexistent propagates ENOENT ---\n");

  // Keep path generation deterministic and dependency-free for lint/test runs.
  static unsigned long no_such_file_seq = 0;
  char path[256];
  snprintf(path, sizeof(path), "/tmp/sfs-no-such-file-%ld-%lu", (long)getpid(),
           ++no_such_file_seq);

  errno = 0;
  int fd = open(path, O_RDONLY);
  T_EQ(fd, -1);
  T_EQ(errno, ENOENT);
}

static void test_system_open_unreadable_propagates_permission(void) {
  printf("\n--- system open unreadable propagates permission ---\n");

  if (getuid() == 0) {
    printf("  SKIP: running as root — permission tests are meaningless\n");
    return;
  }

  char tmpl[] = "/tmp/sfs-no-read-XXXXXX";
  int fd = mkstemp(tmpl);
  T_OK(fd >= 0);
  if (fd < 0) {
    return;
  }

  static const char payload[] = "x";
  ssize_t wrote = write(fd, payload, sizeof(payload));
  T_OK(wrote >= 0);
  T_EQ(close(fd), 0);

  T_EQ(chmod(tmpl, 0333), 0);

  errno = 0;
  int rd = open(tmpl, O_RDONLY);
  T_EQ(rd, -1);
  T_OK(errno == EACCES || errno == EPERM);

  (void)chmod(tmpl, 0600);
  (void)unlink(tmpl);
}

/*
 * Test suite entry point.
 *
 * Tests are organised into four groups:
 *   1. Basic access / open / read / close (uncompressed and compressed)
 *   2. Virtual FD namespace and edge cases (EMFILE, bad data)
 *   3. LRU cache behaviour (string keys, saturation, pinning, eviction)
 *   4. System call pass-through (ENOENT, permission denied)
 */
int main(void) {
  printf("tests/sfs/test-sfs.c\n");
  printf("==============================\n");

  test_access_found_and_missing();
  test_open_read_close_uncompressed();
  test_virtual_fd_namespace_avoids_low_fds();
  test_open_read_stat_compressed();
  test_bad_compressed_open_fails();
  test_lseek_and_emfile();
  test_cache_key_uses_string_equality();
  test_cache_saturation_degrades_without_failure();
  test_cache_cap_soft_when_entries_pinned();
  test_cache_evicts_oldest_unref_entry_under_cap();
  test_system_open_nonexistent_propagates_enoent();
  test_system_open_unreadable_propagates_permission();

  printf("\nSummary: %d passed, %d failed\n", g_passed, g_failed);
  return g_failed ? 1 : 0;
}
