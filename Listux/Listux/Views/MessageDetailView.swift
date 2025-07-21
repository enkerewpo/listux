import SwiftUI

struct MessageDetailView: View {
  var selectedMessage: Message?
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let msg = selectedMessage {
        HStack {
          Text(msg.subject)
            .font(.title2)
            .bold()
          Spacer()
          Button(action: {
            msg.isFavorite.toggle()
          }) {
            Image(systemName: msg.isFavorite ? "star.fill" : "star")
              .foregroundColor(msg.isFavorite ? .yellow : .secondary)
          }
          .buttonStyle(.plain)
        }
        Text(msg.timestamp, style: .date)
          .font(.caption)
          .foregroundColor(.secondary)
        Divider()
        Text("URL: ") + Text(msg.content).font(.caption2).foregroundColor(.secondary)
        Spacer()
      } else {
        Text("No message selected")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding()
  }
}

#Preview {
  MessageDetailView(selectedMessage: nil)
}
