import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(LockStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                Text("StickyKeys")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1)
                Spacer()
                Circle()
                    .fill(store.isLocked ? Color.red : Color.green)
                    .frame(width: 7, height: 7)
            }

            if !store.permitted {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Needs Accessibility permission")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                    Text("To swallow keystrokes, grant StickyKeys under "
                         + "Privacy & Security → Accessibility (and Input Monitoring).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings") { store.requestPermission() }
                        .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                store.toggle()
            } label: {
                Text(store.isLocked ? "Unlock keyboard" : "Lock keyboard for cleaning")
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

            Text("Locking covers the screen and ignores every key, modifier and "
                 + "media key. Unlock with the mouse — this button, the overlay "
                 + "button, or the menu-bar icon. It can’t be unlocked by keyboard.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Spacer()
                Button("Quit StickyKeys") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 300)
        .task { store.refreshPermission() }
    }
}
