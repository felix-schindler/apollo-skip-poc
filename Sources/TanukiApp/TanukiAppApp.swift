import Foundation
import SkipFuse
import SwiftUI

/* SKIP @bridge */public struct TanukiAppRootView : View {
    /* SKIP @bridge */public init() {
    }

    public var body: some View {
        ContentView()
    }
}

/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
/* SKIP @bridge */public final class TanukiAppAppDelegate: Sendable {
    /* SKIP @bridge */public static let shared = TanukiAppAppDelegate()

    private init() {
    }

    /* SKIP @bridge */public func onInit() {
    }

    /* SKIP @bridge */public func onLaunch() {
    }

    /* SKIP @bridge */public func onResume() {
    }

    /* SKIP @bridge */public func onPause() {
    }

    /* SKIP @bridge */public func onStop() {
    }

    /* SKIP @bridge */public func onDestroy() {
    }

    /* SKIP @bridge */public func onLowMemory() {
    }
}
