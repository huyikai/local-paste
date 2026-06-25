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

            TextField(loc("search.placeholder"), text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)

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
        .onChange(of: appState.isSearchFocused) { newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { newValue in
            // Sync back: clicking the search field manually
            if !newValue && appState.isSearchFocused {
                appState.isSearchFocused = false
            }
        }
    }
}
