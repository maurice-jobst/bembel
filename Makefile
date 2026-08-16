.PHONY: build test validate test-data verify-sources format format-check lint

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

# Calls every keyless upstream in data/sources.json and reports dead endpoints
# and collapsed feature counts. Needs the network, so it is a weekly job rather
# than a PR gate; the offline half runs in test-data.
verify-sources:
	python3 scripts/verify_sources.py

format:
	xcrun swift-format format --in-place --recursive $(FORMAT_PATHS)

format-check:
	xcrun swift-format lint --strict --recursive $(FORMAT_PATHS)

lint:
	@command -v swiftlint >/dev/null 2>&1 && swiftlint || echo "swiftlint not installed — skipped"
