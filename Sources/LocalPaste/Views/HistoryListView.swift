import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(appState.filteredItems) { item in
                    ItemRowView(item: item)
                        .environmentObject(appState)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
