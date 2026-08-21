.PHONY: build test validate test-data verify-sources format format-check lint archive testflight icon

FORMAT_PATHS = App Widgets Packages/BEMBELKit/Sources Packages/BEMBELKit/Tests

build:
	xcodebuild -project BEMBEL.xcodeproj -scheme BEMBEL \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

test:
	swift test --package-path Packages/BEMBELKit

# Release archive for a real device. Needs BEMBEL_TEAM_ID in
# Config/Secrets.xcconfig and Xcode signed into that Apple account —
# see docs/TESTFLIGHT.md.
archive:
	xcodebuild -project BEMBEL.xcodeproj -scheme BEMBEL \
		-configuration Release -destination 'generic/platform=iOS' \
		-archivePath build/BEMBEL.xcarchive \
		-allowProvisioningUpdates archive

# Uploads the archive to App Store Connect / TestFlight
# (ExportOptions.plist has destination=upload).
testflight: archive
	xcodebuild -exportArchive -archivePath build/BEMBEL.xcarchive \
		-exportOptionsPlist Config/ExportOptions.plist \
		-exportPath build/export -allowProvisioningUpdates

# Regenerate the app icon (deterministic drawing, never hand-edited).
icon:
	swift scripts/generate_app_icon.swift

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
