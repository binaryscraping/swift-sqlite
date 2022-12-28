.PHONY: build
build:
	@swift build --enable-test-discovery

.PHONY: test
test:
	@swift test --enable-test-discovery

.PHONY: format
format:
	@swiftformat .
