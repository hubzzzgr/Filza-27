import SwiftUI

// Access is granted per target by worse_query. No global kernel/sandbox state.
class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        unsupportedMessage = (major == 26 || major == 27) && MCMBridgeAvailable()
            ? nil : "worse_query requires a supported iOS build and provisioned App Group"
        if let message = unsupportedMessage { exploitStatus = .unsupported(message) }
    }
}
