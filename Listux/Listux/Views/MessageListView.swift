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
          let rootMessages = list.orderedMessages.filter { $0.parent == nil }
          List(selection: $selectedMessage) {
            if list.orderedMessages.isEmpty {
              Text("No messages loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rootMessages.isEmpty {
              Text("No root messages found (all messages have parents)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              ForEach(rootMessages.sorted { $0.seqId < $1.seqId }) { message in
                MessageRowView(message: message, depth: 0)
              }
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

struct MessageRowView: View {
  let message: Message
  let depth: Int
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Main message row
      HStack {
        // Indentation for hierarchy
        HStack(spacing: 4) {
          ForEach(0..<depth, id: \.self) { _ in
            Rectangle()
              .fill(Color.secondary.opacity(0.3))
              .frame(width: 2)
          }
        }
        
        // Expand/collapse button for messages with replies
        if !message.replies.isEmpty {
          Button(action: {
            message.isExpanded.toggle()
          }) {
            Image(systemName: message.isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        } else {
          // Empty space for alignment when no replies
          Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
        }
        
        // Message content
        VStack(alignment: .leading, spacing: 2) {
          Text(message.subject)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(2)
          
          Text(message.timestamp, style: .date)
            .font(.caption2)
            .foregroundColor(.secondary)

          Text(message.messageId)
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        // Favorite button
        Button(action: {
          message.isFavorite.toggle()
        }) {
          Image(systemName: message.isFavorite ? "star.fill" : "star")
            .foregroundColor(message.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      
      // Child messages (replies)
      if message.isExpanded && !message.replies.isEmpty {
        ForEach(message.replies.sorted { $0.seqId < $1.seqId }) { reply in
          MessageRowView(message: reply, depth: depth + 1)
            .padding(.leading, 16)
        }
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
