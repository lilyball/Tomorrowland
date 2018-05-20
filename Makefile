help:
	@echo "Available targets:"
	@echo "  help"
	@echo "  docs"
.PHONY: help

# FIXME: Add --objc when realm/jazzy#976 is fixed
docs: build/ObjC/Tomorrowland
	jazzy \
		--clean \
		--author "Kevin Ballard" \
		--github_url https://github.com/kballard/Tomorrowland \
		--module Tomorrowland \
		--umbrella-header build/ObjC/Tomorrowland/Tomorrowland.h \
		--framework-root build/ObjC \
		--exclude /*/Sources/ObjC/*,/*/Sources/Private/*
.PHONY: docs

build/ObjC/Tomorrowland:
	mkdir -p build/ObjC
	ln -s ../../Sources/ObjC build/ObjC/Tomorrowland
.INTERMEDIATE: build/ObjC/Tomorrowland
