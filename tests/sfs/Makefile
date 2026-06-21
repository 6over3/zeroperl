# tests/sfs/Makefile
# Build and run SFS baseline tests natively on macOS/Linux.
#
# Usage:
#   make             # build + run both test suites
#   make test-sfs    # compile + run C harness only
#   make test-gen    # run Node.js generator tests only
#   make clean       # remove build artifacts

CC       ?= cc
CFLAGS   ?= -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -O0 -g
TEST_DEFS ?= -DSFS_LRU_MAX=8 -DSFS_LRU_CAP_BYTES=256
# Cross-platform LZ4 detection: pkg-config (Linux/Debian) first, then Homebrew (macOS)
LZ4_CFLAGS := $(shell pkg-config --cflags liblz4 2>/dev/null)
LZ4_LIBS   := $(shell pkg-config --libs liblz4 2>/dev/null)
ifeq ($(LZ4_CFLAGS),)
    LZ4_PREFIX := $(shell brew --prefix lz4 2>/dev/null || echo /usr/local)
    LZ4_CFLAGS := -I$(LZ4_PREFIX)/include
    LZ4_LIBS   := -L$(LZ4_PREFIX)/lib -llz4
endif
CFLAGS     += $(TEST_DEFS)
CFLAGS     += $(LZ4_CFLAGS)
CFLAGS     += -I../../stubs
CFLAGS     += -I../../gen
LDFLAGS    ?= $(LZ4_LIBS)
BINARY    = /tmp/test-sfs-zeroperl

.PHONY: all test-sfs test-gen clean

all: test-sfs test-gen

test-sfs: $(BINARY)
	@echo "=== Running test-sfs.c ==="
	$(BINARY)

$(BINARY): test-sfs.c ../../stubs/sfs_runtime.c ../../stubs/sfs_runtime.h ../../stubs/sfs_compression.c ../../stubs/sfs_compression.h ../../stubs/sfs_lz4.h
	$(CC) $(CFLAGS) -o $@ test-sfs.c ../../stubs/sfs_runtime.c ../../stubs/sfs_compression.c $(LDFLAGS)

test-gen:
	@echo "=== Running test-generator.js ==="
	node test-generator.js

clean:
	rm -f $(BINARY)
