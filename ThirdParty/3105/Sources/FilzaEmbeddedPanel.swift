import SwiftUI
import UIKit

/// Canonical embedded-app chrome for Filza 27.
///
/// This intentionally matches the presentation contract originally used by the
/// embedded 3105 workspace: persistent material Close bar, divider, large page
/// sheet, visible grabber, and no extra navigation controller around the app's
/// own SwiftUI hierarchy.
struct FilzaEmbeddedPanel<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAccessStatus = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                }

                Spacer()
                Button {
                    showAccessStatus = true
                } label: {
                    Label("worse_query only", systemImage: "info.circle")
                        .font(.caption)
                }
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAccessStatus) { FilzaAccessStatusView() }
    }
}

private struct FilzaAccessStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var observations: [String: String] = [:]
    @State private var groupInput = ""
    @State private var groupStatus = ""
    @State private var setupMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Access backend") {
                    Text("worse_query only")
                    Text("No MobileHouseArrest, CMG, kernel exploit, or fallback exploit is enabled.")
                    Text(groupStatus)
                    Text("A provisioned, dedicated App Group is required. A successful build does not verify device compatibility.")
                }
                Section("App Group setup") {
                    TextField("group.your.provisioned.identifier", text: $groupInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use a dedicated, disposable App Group: worse_query replaces its Library/Caches. Do not use another app's shared data group.")
                    Button("Save and check App Group") {
                        if let problem = FilzaWorseQueryConfigureGroup(groupInput) {
                            setupMessage = problem
                        } else {
                            setupMessage = "Setting saved. Restart Filza to refresh discovery, then request access again."
                        }
                        reload()
                    }
                    Button("Use packaged setting") {
                        _ = FilzaWorseQueryConfigureGroup("")
                        groupInput = FilzaWorseQueryGroupIdentifier()
                        setupMessage = "Packaged setting selected. Restart Filza to refresh discovery."
                        reload()
                    }
                    if !setupMessage.isEmpty { Text(setupMessage).font(.caption) }
                    Text("This setting cannot create a signing entitlement. The group must already be in this app's provisioning profile and signed entitlements.")
                }
                Section("Feature status") {
                    Text("Files and containers: checked per operation")
                    Text("Gestalt and PosterBoard: depend on access to their exact targets")
                    Text("ByeTunes, pairing, WebDAV and SSH: device behavior unverified")
                    Text("No feature is marked working merely because an access handle was returned. Write access is not tested by this status view.")
                }
                Section("Last observed target access") {
                    if observations.isEmpty {
                        Text("No target access observed in this session.")
                    }
                    ForEach(observations.keys.sorted(), id: \.self) { path in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(path).font(.caption).textSelection(.enabled)
                            Text(observations[path] ?? "Unverified").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("These are historical read observations from normal access requests. Handles may since have been released; current access may differ.")
                    Button("Refresh status") { reload() }
                }
            }
            .navigationTitle("worse_query status")
            .toolbar { Button("Done") { dismiss() } }
            .onAppear { groupInput = FilzaWorseQueryGroupIdentifier(); reload() }
        }
    }

    private func reload() {
        observations = FilzaWorseQueryObservedAccess()
        groupStatus = FilzaWorseQueryConfigurationStatus()
    }
}

enum FilzaEmbeddedPanelPresentation {
    @MainActor
    static func configure(_ controller: UIViewController) {
        controller.modalPresentationStyle = .pageSheet
        guard let sheet = controller.sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.selectedDetentIdentifier = .large
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }
}
