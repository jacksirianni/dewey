import SwiftUI

@main
struct DeweyApp: App {
    @State private var store = DeweyStore()

    /// **Two stores, side by side, on purpose** (§17). `DeweyStore` is what a
    /// reader has read and thought; `SessionStore` is who the reader is. They
    /// change for different reasons, fail for different reasons, and only meet
    /// in `RootView`, which hands the account to the store and never the
    /// reverse. Folding identity into `DeweyStore` would have put a network
    /// call behind `store.me`.
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(session)
                .tint(Theme.Palette.accent)
        }
    }
}
