help:
	@echo "Available targets:"
	@echo "  help"
	@echo "  docs"
.PHONY: help

# FIXME: Build both ObjC and Swift docs once Jazzy supports this natively.
# In 0.13.0 it's possible if I run sourcekitten manually, but I'm not sure how
# to do that, and I'm pretty sure the generated documentation won't have a
# toggle between objc and swift.
docs:
	@rm -rf build
	@mkdir -p build/ObjC
	@ln -s ../../Sources/ObjC build/ObjC/Tomorrowland
	jazzy \
		--clean \
		--author "Lily Ballard" \
		--github_url https://github.com/lilyball/Tomorrowland \
		--module Tomorrowland \
		--umbrella-header build/ObjC/Tomorrowland/Tomorrowland.h \
		--framework-root build/ObjC \
		--exclude /*/Sources/ObjC/*,/*/Sources/Private/*
.PHONY: docs
