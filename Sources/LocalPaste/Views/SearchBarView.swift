import SwiftUI

struct SearchBarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField(loc("search.placeholder"), text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .onChange(of: appState.isSearchFocused) { newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { newValue in
            if newValue && !appState.isSearchFocused {
                appState.isSearchFocused = true
            } else if !newValue && appState.isSearchFocused {
                appState.isSearchFocused = false
            }
        }
    }
}
