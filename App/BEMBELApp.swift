import BEMBELKit
import SwiftUI

@main
struct BEMBELApp: App {
    var body: some Scene {
        WindowGroup {
            // Placeholder until the navigation shell lands (BEM-A03).
            VStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                Text(verbatim: "BEMBEL")
                    .font(.title.weight(.bold))
            }
        }
    }
}
