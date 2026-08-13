import Testing

@testable import BEMBELKit

@Test func kitVersionIsSemanticVersion() {
    let parts = BEMBELKitInfo.version.split(separator: ".")
    #expect(parts.count == 3)
    #expect(parts.allSatisfy { Int($0) != nil })
}
