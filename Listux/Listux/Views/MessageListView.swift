import SwiftUI

struct MessageListView: View {
  var selectedSidebarTab: SidebarTab
  var selectedList: MailingList?
  @Binding var selectedMessage: Message?
  var isLoading: Bool
  /// URL for the next (older) page, if available
  var nextURL: String?
  /// URL for the previous (newer) page, if available
  var prevURL: String?
  /// URL for the latest page, if available
  var latestURL: String?
  /// Current page number
  var currentPage: Int = 1
  /// Callback when a pagination button is tapped
  var onPageLinkTapped: ((String) -> Void)?
  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        // Main message list
        if let list = selectedList, selectedSidebarTab == .lists {
          List(selection: $selectedMessage) {
            ForEach(list.orderedMessages.sorted { $0.seqId < $1.seqId }) { message in
              HStack {
                Text(message.subject)
                Spacer()
                Text(message.timestamp, style: .date)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Button(action: {
                  message.isFavorite.toggle()
                }) {
                  Image(systemName: message.isFavorite ? "star.fill" : "star")
                    .foregroundColor(message.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
              }
              .contentShape(Rectangle())
            }
          }
          .listStyle(.inset)
        } else {
          Text("Select a list to view messages")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      // Overlay loading indicator
      if isLoading {
        Color.black.opacity(0.1)
          .ignoresSafeArea()
        ProgressView("Loading messages...")
          .padding(32)
          .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
          .shadow(radius: 8)
      }
    }
  }
}

#Preview {
  MessageListView(
    selectedSidebarTab: .lists, selectedList: nil, selectedMessage: .constant(nil),
    isLoading: false,
    nextURL: nil, prevURL: nil, latestURL: nil, onPageLinkTapped: nil
  )
}
