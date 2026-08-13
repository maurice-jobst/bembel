import BEMBELKit
import SwiftUI

@main
struct BEMBELApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    router.handle(url)
                }
        }
    }
}
