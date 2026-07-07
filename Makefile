# LocalFlow — build and package without full Xcode (Command Line Tools only).
#
#   make app                     Build LocalFlow.app (fetches whisper.cpp first)
#   make test                    Run the unit test suite
#   make run                     Build and launch the app
#   make clean                   Remove build products
#
# Signing: ad-hoc by default. Ad-hoc signatures change on every build, which
# makes macOS forget the app's Accessibility grant across rebuilds. If you
# have a real signing identity, use it for a stable signature:
#   make app CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"

CODESIGN_IDENTITY ?= -
CONFIG ?= release
APP := LocalFlow.app
BINARY := .build/$(CONFIG)/LocalFlow

.PHONY: all app build fetch test run clean

all: app

fetch:
	./scripts/fetch-whisper.sh

build: fetch
	swift build -c $(CONFIG)
	# With full Xcode (+ Metal toolchain: xcodebuild -downloadComponent
	# MetalToolchain), precompile the shaders into the SwiftPM resource
	# bundle so dev/CLI runs skip the runtime JIT compile. Optional — without
	# it ggml JIT-compiles the shipped shader source instead.
	@if xcrun metal --version >/dev/null 2>&1; then \
		xcrun metal -O2 -Wno-unused-const-variable \
			-o .build/$(CONFIG)/whisper_whisper.bundle/default.metallib \
			Vendor/metal-resources/ggml-metal.metal && \
		echo "Precompiled Metal shaders into whisper_whisper.bundle"; \
	else \
		echo "Metal toolchain not available — shaders will be JIT-compiled at runtime"; \
	fi

test: fetch
	./scripts/test.sh

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY) $(APP)/Contents/MacOS/LocalFlow
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	# Self-contained Metal shader source; ggml JIT-compiles it at startup so
	# Whisper runs on the GPU (falls back to CPU if missing).
	cp Vendor/metal-resources/ggml-metal.metal $(APP)/Contents/Resources/
	codesign --force --sign "$(CODESIGN_IDENTITY)" $(APP)
	@echo "Built $(APP)"

run: app
	open $(APP)

clean:
	rm -rf .build $(APP)
