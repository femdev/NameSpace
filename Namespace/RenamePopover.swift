// SwiftUI text-field popover for entering/editing a Space name. Trims input, disables
// Save when empty, commits on Enter. Presented from the status-bar menu.

import SwiftUI

struct RenamePopover: View {
    @State private var name: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(initial: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self._name = State(initialValue: initial)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name this Space")
                .font(.headline)
            TextField("e.g. Work", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(14)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}
