import SwiftUI
import SwiftData

struct MailingListView: View {
  let mailingLists: [MailingList]
  let isLoading: Bool
  let onAppear: () -> Void
  @State private var selectedList: MailingList? = nil
  @State private var showMessages: Bool = false

  var body: some View {
    List(mailingLists, id: \ .id) { list in
      NavigationLink(destination: MailingListMessageView(mailingList: list)) {
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

struct MailingListMessageView: View {
  let mailingList: MailingList
  @State private var isLoading: Bool = false
  @State private var messages: [Message] = []
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]
  
  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      return new
    }
  }

  var body: some View {
    SimpleMessageListView(
      messages: messages,
      title: mailingList.name,
      isLoading: isLoading
    )
    .onAppear {
      loadMessages()
    }
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
