import SwiftUI

struct MessageListView: View {
  var selectedSidebarTab: SidebarTab
  var selectedList: MailingList?
  @Binding var selectedMessage: Message?
  var isLoading: Bool
  var body: some View {
    VStack {
      if isLoading {
        ProgressView("Loading messages...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let list = selectedList, selectedSidebarTab == .lists {
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
  }
}

#Preview {
  MessageListView(
    selectedSidebarTab: .lists, selectedList: nil, selectedMessage: .constant(nil), isLoading: false
  )
}
