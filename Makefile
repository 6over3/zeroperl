PERL_VERSION = 5.40.0
WASI_SDK_VERSION = 25.0
BUILD_EXIFTOOL = true

# Detect OS
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    MKDIR = if not exist $(1) mkdir $(1)
    RM = if exist $(1) rmdir /s /q $(1)
    RMFILE = if exist $(1) del /q $(1)
    WGET = curl -L -o
    PATHSEP = \\
else
    DETECTED_OS := $(shell uname -s)
    MKDIR = mkdir -p $(1)
    RM = rm -rf $(1)
    RMFILE = rm -f $(1)
    WGET = wget -q -O
    PATHSEP = /
endif

PERL_URL = https://www.cpan.org/src/5.0/perl-$(PERL_VERSION).tar.gz
WASI_SDK_URL = https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-$(WASI_SDK_VERSION)/wasi-sdk-$(WASI_SDK_VERSION).0-x86_64-linux.tar.gz
BINARYEN_URL = https://github.com/WebAssembly/binaryen/releases/download/version_121/binaryen-version_121-x86_64-linux.tar.gz

BUILD_DIR = build
NATIVE_DIR = $(BUILD_DIR)$(PATHSEP)native
WASM_DIR = $(BUILD_DIR)$(PATHSEP)wasm
DEPS_DIR = $(BUILD_DIR)$(PATHSEP)deps

.PHONY: all help clean setup native-perl wasi-perl bundle distclean test-os

all: bundle

help:
	@echo "zeroperl build system ($(detected_os))"
	@echo "targets:"
	@echo "  all        - build complete zeroperl"
	@echo "  setup      - install wasi sdk and binaryen"
	@echo "  native-perl - build native perl"
	@echo "  wasi-perl  - cross-compile perl to wasi"
	@echo "  bundle     - create final webassembly bundle"
	@echo "  clean      - remove build artifacts"
	@echo "  distclean  - remove all downloads"
	@echo "  test-os    - test os detection"

test-os:
	@echo "Detected OS: $(DETECTED_OS)"
	@echo "Path separator: $(PATHSEP)"
	@echo "Build dir: $(BUILD_DIR)"
	@echo "Native dir: $(NATIVE_DIR)"

setup:
	@echo "Setting up dependencies for $(DETECTED_OS)..."
	$(call MKDIR,$(BUILD_DIR))
	$(call MKDIR,$(DEPS_DIR))
ifeq ($(DETECTED_OS),Windows)
	@echo "windows detected - use wsl or github actions for full build"
else
	$(WGET) $(DEPS_DIR)/wasi-sdk.tar.gz $(WASI_SDK_URL)
	cd $(DEPS_DIR) && tar xf wasi-sdk.tar.gz
	cd $(DEPS_DIR) && mv wasi-sdk-$(WASI_SDK_VERSION).0-x86_64-linux wasi-sdk
	$(WGET) $(DEPS_DIR)/binaryen.tar.gz $(BINARYEN_URL)
	cd $(DEPS_DIR) && tar xf binaryen.tar.gz
	cd $(DEPS_DIR) && mv binaryen-version_121 binaryen
	@echo "dependencies installed"
endif

native-perl:
	@echo "Building native Perl for $(DETECTED_OS)..."
	$(call MKDIR,$(NATIVE_DIR))
ifeq ($(DETECTED_OS),Windows)
	@echo "windows detected - use wsl or github actions for full build"
else
	$(WGET) $(NATIVE_DIR)/perl.tar.gz $(PERL_URL)
	cd $(NATIVE_DIR) && tar xf perl.tar.gz --strip-components=1
	cd $(NATIVE_DIR) && sh Configure -sde -Dprefix="$(CURDIR)/$(NATIVE_DIR)/prefix" -Dusedevel
	cd $(NATIVE_DIR) && make -j4 && make install
	@echo "native perl built"
endif

wasi-perl: native-perl setup
	@echo "Cross-compiling Perl to WASI..."
	$(call MKDIR,$(WASM_DIR))
ifeq ($(DETECTED_OS),Windows)
	@echo "windows detected - use wsl or github actions for full build"
else
	$(WGET) $(WASM_DIR)/perl.tar.gz $(PERL_URL)
	cd $(WASM_DIR) && tar xf perl.tar.gz --strip-components=1
	cd $(WASM_DIR) && patch -p1 < ../patches/glob.patch || true
	cd $(WASM_DIR) && patch -p1 < ../patches/stat.patch || true
	cd $(WASM_DIR) && PATH="$(CURDIR)/wasi-bin:$$PATH" WASI_SDK_PATH="$(CURDIR)/$(DEPS_DIR)/wasi-sdk" wasiconfigure sh Configure -sde -Dosname=wasi
	cd $(WASM_DIR) && PATH="$(CURDIR)/wasi-bin:$$PATH" wasimake make
	@echo "wasi perl built"
endif

bundle: wasi-perl
	@echo "Creating WebAssembly bundle..."
ifeq ($(DETECTED_OS),Windows)
	@echo "windows detected - use wsl or github actions for full build"
else
	node tools/sfs.js -i /zeroperl -o build/zeroperl.h --prefix /zeroperl || echo "filesystem bundle skipped"
	@echo "WebAssembly bundle created"
endif

clean:
	@echo "Cleaning build artifacts..."
	$(call RM,$(NATIVE_DIR))
	$(call RM,$(WASM_DIR))

distclean:
	@echo "Removing all build files..."
	$(call RM,$(BUILD_DIR))