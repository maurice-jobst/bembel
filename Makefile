.PHONY: build test validate test-data format format-check lint

FORMAT_PATHS = App Widgets Packages/BEMBELKit/Sources Packages/BEMBELKit/Tests

build:
	xcodebuild -project BEMBEL.xcodeproj -scheme BEMBEL \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

test:
	swift test --package-path Packages/BEMBELKit

validate:
	python3 scripts/validate_data.py

# The validator's own tests: every rule gets watched failing at least once.
test-data:
	cd scripts && python3 -m unittest discover -p 'test_*.py' -v

format:
	xcrun swift-format format --in-place --recursive $(FORMAT_PATHS)

format-check:
	xcrun swift-format lint --strict --recursive $(FORMAT_PATHS)

lint:
	@command -v swiftlint >/dev/null 2>&1 && swiftlint || echo "swiftlint not installed — skipped"
