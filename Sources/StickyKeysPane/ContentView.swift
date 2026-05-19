import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(LockStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.permitted { permissionBanner }

                    Button {
                        store.toggle()
                    } label: {
                        Text(store.isLocked
                             ? "Unlock keyboard"
                             : "Lock keyboard for cleaning")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.isLocked ? .red : .accentColor)
                    .controlSize(.large)

                    HStack(spacing: 6) {
                        Text("Auto-unlock")
                            .font(.system(size: 12))
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { store.autoUnlockSeconds },
                                set: { store.autoUnlockSeconds = $0 }
                            ),
                            in: 30...600, step: 30
                        ) {
                            Text("\(store.autoUnlockSeconds)s")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .disabled(store.isLocked)
                    }

                    Text("Locking covers the screen and ignores every key, "
                         + "modifier and media key. Unlock with the mouse — "
                         + "this button, the overlay button, or the menu-bar "
                         + "icon. It can’t be unlocked by keyboard.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 340, height: 540)
        .task { store.refreshPermission() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.system(size: 13))
                .foregroundStyle(.tint)
            Text("STICKYKEYS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Needs Accessibility permission")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
            Text("To swallow keystrokes, grant “\(store.hostAppName)” "
                 + "under Privacy & Security → Accessibility (and "
                 + "Input Monitoring). When merged, the host is "
                 + "MattsSoftware — not StickyKeys.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Open Privacy Settings") { store.requestPermission() }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .controlSize(.small)
            .help("Quit StickyKeys")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
