import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SwitchCore
import SwitchMac
import SwitchStorage

enum AccountTransferMode: Identifiable {
    case export, importing
    var id: Self { self }
}

extension AppState {
    var canTransferAccounts: Bool { startupAccess.isReady && !demo && libraryReadable && !working && !transferringAccounts }
    private var transferType: UTType { UTType(filenameExtension: "switchtransfer", conformingTo: .data) ?? .data }

    @MainActor func exportAccounts(passphrase: String) async {
        guard canTransferAccounts else { return }
        transferringAccounts = true; defer { transferringAccounts = false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [transferType]
        panel.nameFieldStringValue = "ClaudeSwitch-accounts.switchtransfer"
        panel.canCreateDirectories = true
        guard await panel.begin() == .OK, let destination = panel.url else { return }
        await saveCurrentLogin()
        await RuntimeLog.shared.record(.exportStarted, component: .operation)
        do {
            var state = library
            state.accounts = knownAccounts
            let count = try await engine.exportData(library: state, passphrase: passphrase, to: destination)
            await RuntimeLog.shared.record(.exportCompleted, component: .operation)
            message = L10n.tr("Accounts exported: {0}.", L10n.argument(count))
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            await RuntimeLog.shared.record(.failed, component: .operation, level: .error, failure: RuntimeFailure(error))
            message = (error as? SwitchError)?.localizedDescription ?? L10n.tr("Could not export accounts.")
        }
    }

    @MainActor func importAccounts(passphrase: String) async {
        guard canTransferAccounts else { return }
        transferringAccounts = true; defer { transferringAccounts = false }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [transferType]
        panel.allowsMultipleSelection = false
        guard await panel.begin() == .OK, let source = panel.url else { return }
        await RuntimeLog.shared.record(.importStarted, component: .operation)
        do {
            let outcome = try await engine.importData(from: source, passphrase: passphrase)
            library = outcome.merged(into: library)
            persist()
            await RuntimeLog.shared.record(.importCompleted, component: .operation)
            message = L10n.tr("Accounts imported: {0}. Skipped: {1}. Failed: {2}.", L10n.argument(outcome.importedAccountIDs.count),
                              L10n.argument(outcome.skipped), L10n.argument(outcome.failed))
            await refresh()
        } catch {
            await RuntimeLog.shared.record(.failed, component: .operation, level: .error, failure: RuntimeFailure(error))
            message = (error as? SwitchError)?.localizedDescription ?? L10n.tr("Could not import accounts.")
        }
    }
}

struct AccountTransferSheet: View {
    let mode: AccountTransferMode
    let confirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var passphrase = ""
    @State private var confirmation = ""
    private var exporting: Bool { mode == .export }
    private var hint: String? {
        guard exporting else { return nil }
        if passphrase.count < SwitchEngine.minimumTransferPassphraseLength {
            return L10n.tr("Use at least {0} characters.", L10n.argument(SwitchEngine.minimumTransferPassphraseLength))
        }
        return confirmation.isEmpty || confirmation == passphrase ? nil : L10n.tr("Passwords don't match.")
    }
    private var ready: Bool { exporting ? hint == nil && confirmation == passphrase : !passphrase.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exporting ? L10n.tr("Export accounts") : L10n.tr("Import accounts")).font(.headline)
            Text(exporting ? L10n.tr("Set a password for this file. Anyone with the file and password can sign in to these accounts.")
                           : L10n.tr("Enter the password set when this file was exported."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SecureField(L10n.tr("Password"), text: $passphrase)
            if exporting { SecureField(L10n.tr("Confirm password"), text: $confirmation) }
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.tr("Choose File…")) { dismiss(); confirm(passphrase) }
                    .keyboardShortcut(.defaultAction).disabled(!ready)
            }
        }
        .padding(20).frame(width: 380)
    }
}
