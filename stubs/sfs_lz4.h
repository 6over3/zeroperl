#ifndef ZEROPERL_SFS_LZ4_H
#define ZEROPERL_SFS_LZ4_H

#include <errno.h>
#include <stdbool.h>
#include <stddef.h>

#include <lz4frame.h>

typedef struct {
  const unsigned char *srcp;
  size_t src_rem;
  unsigned char *dstp;
  size_t dst_rem;
} SfsLz4State;

// Centralized failure path keeps EIO policy and context cleanup consistent.
static inline int sfs_lz4_fail(LZ4F_dctx *ctx) {
  LZ4F_freeDecompressionContext(ctx);
  errno = EIO;
  return -1;
}

// Phase 1 writes directly into the destination buffer until either the frame
// completes or the destination fills up.
static inline int sfs_lz4_phase1(LZ4F_dctx *ctx, SfsLz4State *state) {
  while (state->dst_rem > 0) {
    size_t src_chunk = state->src_rem;
    size_t dst_chunk = state->dst_rem;
    size_t hint = LZ4F_decompress(ctx, state->dstp, &dst_chunk, state->srcp,
                                  &src_chunk, NULL);

    if (LZ4F_isError(hint)) {
      return sfs_lz4_fail(ctx);
    }

    state->srcp += src_chunk;
    state->src_rem -= src_chunk;
    state->dstp += dst_chunk;
    state->dst_rem -= dst_chunk;

    if (hint == 0) {
      if (state->dst_rem != 0) {
        return sfs_lz4_fail(ctx);
      }
      return 0;
    }

    if (src_chunk == 0 && dst_chunk == 0) {
      return sfs_lz4_fail(ctx);
    }

    if (state->src_rem == 0 && hint != 0 && state->dst_rem > 0) {
      return sfs_lz4_fail(ctx);
    }
  }

  return 1;
}

// Phase 2 drains frame trailer/checksum bytes after output is full.
static inline int sfs_lz4_phase2(LZ4F_dctx *ctx, SfsLz4State *state) {
  unsigned char scratch[64];

  for (;;) {
    size_t src_chunk = state->src_rem;
    size_t dst_chunk = sizeof(scratch);
    size_t hint = LZ4F_decompress(ctx, scratch, &dst_chunk, state->srcp,
                                  &src_chunk, NULL);

    if (LZ4F_isError(hint)) {
      return sfs_lz4_fail(ctx);
    }

    state->srcp += src_chunk;
    state->src_rem -= src_chunk;

    if (dst_chunk != 0) {
      return sfs_lz4_fail(ctx);
    }

    if (hint == 0) {
      return 0;
    }

    if (src_chunk == 0) {
      return sfs_lz4_fail(ctx);
    }
  }
}

/* Shared SFS LZ4 frame decompression path used by runtime and tests.
 *
 * Decompresses an LZ4 frame at src[0..src_len) into dst[0..dst_len).
 * dst_len must equal the exact uncompressed size.  Returns 0 on success,
 * -1 on error (errno set to EIO, ENOMEM, or EINVAL).
 *
 * Two common patterns for LZ4F_decompress completing the frame:
 *
 * (a) Everything in one call: hint=0, all src consumed, all dst written.
 * (b) Dst fills before hint=0: output buffer exactly full, but the frame
 *     still has trailing bytes (end mark + optional content checksum).
 *     A scratch-buffer drain loop is needed to let LZ4F finish.
 */
static inline int sfs_lz4_decompress_frame(const unsigned char *src,
                                           size_t src_len,
                                           unsigned char *dst,
                                           size_t dst_len) {
  if (!src || !dst) {
    errno = EINVAL;
    return -1;
  }

  LZ4F_dctx *ctx = NULL;
  size_t cctx_res = LZ4F_createDecompressionContext(&ctx, LZ4F_VERSION);
  if (LZ4F_isError(cctx_res) || !ctx) {
    errno = ENOMEM;
    return -1;
  }

  SfsLz4State state = {
      .srcp = src,
      .src_rem = src_len,
      .dstp = dst,
      .dst_rem = dst_len,
  };

  int phase1 = sfs_lz4_phase1(ctx, &state);
  if (phase1 < 0) {
    return -1;
  }
  if (phase1 == 0) {
    LZ4F_freeDecompressionContext(ctx);
    return 0;
  }

  if (sfs_lz4_phase2(ctx, &state) != 0) {
    return -1;
  }

  LZ4F_freeDecompressionContext(ctx);
  return 0;
}

#endif
