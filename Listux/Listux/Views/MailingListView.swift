import SwiftUI

struct MailingListView: View {
  let mailingLists: [MailingList]
  let isLoading: Bool
  let onAppear: () -> Void
  @State private var selectedList: MailingList? = nil
  @State private var showMessages: Bool = false

  var body: some View {
    List(mailingLists, id: \ .id) { list in
      NavigationLink(destination: MessageListViewForList(mailingList: list)) {
        VStack(alignment: .leading) {
          Text(list.name)
            .font(.headline)
          Text(list.desc)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
    }
    .navigationTitle("Mailing Lists")
    .onAppear(perform: onAppear)
    .overlay(
      Group {
        if isLoading {
          ProgressView("Loading...")
        }
      }
    )
  }
}

struct MessageListViewForList: View {
  let mailingList: MailingList
  @State private var selectedMessage: Message? = nil
  @State private var isLoading: Bool = false
  @State private var messages: [Message] = []

  var body: some View {
    List(messages, id: \ .messageId) { message in
      NavigationLink(destination: MessageDetailView(selectedMessage: message)) {
        VStack(alignment: .leading) {
          Text(message.subject)
            .font(.headline)
          Text(message.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .navigationTitle(mailingList.name)
    .onAppear {
      loadMessages()
    }
    .overlay(
      Group {
        if isLoading {
          ProgressView("Loading...")
        }
      }
    )
  }

  private func loadMessages() {
    isLoading = true
    Task {
      do {
        let html = try await NetworkService.shared.fetchListPage(mailingList.name)
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: mailingList)
        await MainActor.run {
          messages = result.messages
          isLoading = false
        }
      } catch {
        await MainActor.run {
          isLoading = false
        }
      }
    }
  }
} 
