import SwiftUI

struct TaggedMessagesView: View {
  let tag: String
  let messages: [Message]
  @Binding var selectedMessage: Message?
  let preference: Preference

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Tag: \(tag)")
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()
        Text("\(messages.count) message\(messages.count == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      #if os(macOS)
        .background(Color(.windowBackgroundColor).opacity(0.95))
      #else
        .background(Color(.systemGroupedBackground))
      #endif

      Divider()

      if messages.isEmpty {
        Text("No messages with tag '\(tag)'")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedMessage) {
          ForEach(messages, id: \.messageId) { message in
            TaggedMessageRowView(
              message: message, preference: preference, selectedMessage: $selectedMessage
            )
            .onTapGesture {
              withAnimation(Animation.userPreferenceQuick) {
                selectedMessage = message
              }
            }
          }
        }
        #if os(macOS)
          .listStyle(.inset)
        #else
          .listStyle(.insetGrouped)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
}
