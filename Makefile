.PHONY: build test validate lint

build:
	xcodebuild -project BEMBEL.xcodeproj -scheme BEMBEL \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

test:
	swift test --package-path Packages/BEMBELKit

validate:
	python3 scripts/validate_data.py

lint:
	@command -v swiftlint >/dev/null 2>&1 && swiftlint || echo "swiftlint not installed — skipped"
