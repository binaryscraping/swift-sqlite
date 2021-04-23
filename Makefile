.PHONY: build
build:
	@swift build --enable-test-discovery

.PHONY: test
test:
	@swift test --enable-test-discovery

.PHONY: format
format:
	@swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Sources \
		./Tests \
		./Package.swift
