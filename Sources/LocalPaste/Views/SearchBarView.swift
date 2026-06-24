import SwiftUI

struct SearchBarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField("Search…", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .onAppear {
                    // Auto-focus after a short delay to ensure view is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: isFocused) { appState.isSearchFocused = $0 }
    }
}
