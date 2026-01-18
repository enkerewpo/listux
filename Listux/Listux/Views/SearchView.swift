import SwiftUI
import SwiftSoup

struct SearchView: View {
  @State private var searchQuery: String = ""
  @State private var searchResults: [Message] = []
  @State private var isLoading: Bool = false
  @State private var hasSearched: Bool = false
  @State private var currentPage: Int = 1
  @State private var nextURL: String?
  @State private var prevURL: String?
  @State private var latestURL: String?
  @State private var errorMessage: String?
  @Binding var selectedMessage: Message?
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Search bar
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14))
          .foregroundColor(.secondary)

        TextField("Search all mailing lists...", text: $searchQuery)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
          .focused($isSearchFocused)
          .onSubmit {
            performSearch()
          }

        if !searchQuery.isEmpty {
          Button(action: {
            searchQuery = ""
            searchResults = []
            hasSearched = false
            errorMessage = nil
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }

        Button(action: {
          performSearch()
        }) {
          Text("Search")
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(searchBarBackgroundColor)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(
                isSearchFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
          )
      )
      .padding(.horizontal, 16)
      .padding(.top, 12)

      Divider()

      // Search results or empty state
      if isLoading {
        ProgressView("Searching...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = errorMessage {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 32))
            .foregroundColor(.orange)
          Text("Search Error")
            .font(.system(size: 16, weight: .semibold))
          Text(error)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else if hasSearched && searchResults.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 32))
            .foregroundColor(.secondary)
          Text("No results found")
            .font(.system(size: 16, weight: .semibold))
          Text("Try a different search query")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if hasSearched {
        // Search results list
        VStack(spacing: 0) {
          // Results count
          HStack {
            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)

          Divider()

          // Messages list
          List(selection: $selectedMessage) {
            ForEach(searchResults, id: \.messageId) { message in
              MessageRowView(message: message, isSelected: selectedMessage == message)
                .onTapGesture {
                  selectedMessage = message
                }
            }
          }
          .listStyle(.plain)

          // Pagination controls
          if nextURL != nil || prevURL != nil || latestURL != nil {
            Divider()
            HStack(spacing: 12) {
              if let latest = latestURL {
                Button(action: {
                  loadPage(url: latest, page: 1)
                }) {
                  Text("Latest")
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
              }

              if let prev = prevURL {
                Button(action: {
                  loadPage(url: prev, page: max(1, currentPage - 1))
                }) {
                  HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                      .font(.system(size: 10))
                    Text("Previous")
                      .font(.system(size: 12))
                  }
                }
                .buttonStyle(.bordered)
              }

              Spacer()

              Text("Page \(currentPage)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

              Spacer()

              if let next = nextURL {
                Button(action: {
                  loadPage(url: next, page: currentPage + 1)
                }) {
                  HStack(spacing: 4) {
                    Text("Next")
                      .font(.system(size: 12))
                    Image(systemName: "chevron.right")
                      .font(.system(size: 10))
                  }
                }
                .buttonStyle(.bordered)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
          }
        }
      } else {
        // Initial state - show search tips
        VStack(spacing: 16) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text("Search All Mailing Lists")
            .font(.system(size: 18, weight: .semibold))
          Text("Enter a search query to find messages across all mailing lists")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

          VStack(alignment: .leading, spacing: 8) {
            Text("Search Tips:")
              .font(.system(size: 14, weight: .semibold))
              .padding(.top, 16)

            SearchTipRow(prefix: "s:", description: "Search in subject")
            SearchTipRow(prefix: "f:", description: "Search in From header")
            SearchTipRow(prefix: "t:", description: "Search in To header")
            SearchTipRow(prefix: "b:", description: "Search in message body")
            SearchTipRow(prefix: "d:", description: "Search by date range")
          }
          .frame(maxWidth: 400)
          .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    #if os(iOS)
      .sheet(item: $selectedMessage) { message in
        NavigationStack {
          MessageDetailView(selectedMessage: message)
            .navigationTitle("Message Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                  selectedMessage = nil
                }
              }
            }
        }
      }
    #endif
  }

  private var searchBarBackgroundColor: Color {
    #if os(macOS)
      Color(.controlBackgroundColor)
    #else
      Color(.systemGray6)
    #endif
  }

  private func performSearch() {
    let query = searchQuery.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return }

    isLoading = true
    hasSearched = true
    errorMessage = nil
    currentPage = 1
    searchResults = []

    Task {
      do {
        let html = try await SearchService.shared.search(query: query, page: 1)
        let result = Parser.parseSearchResults(from: html)

        await MainActor.run {
          searchResults = result.messages
          nextURL = result.nextURL
          prevURL = result.prevURL
          latestURL = result.latestURL
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }

  private func loadPage(url: String, page: Int) {
    guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    isLoading = true

    Task {
      do {
        // Extract query from current search
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        
        // Build full URL if needed
        var fullURL = url
        if !url.hasPrefix("http") {
          if url.hasPrefix("/") {
            fullURL = LORE_LINUX_BASE_URL.value + url
          } else {
            fullURL = LORE_LINUX_BASE_URL.value + "/all/" + url
          }
        }

        let html = try await NetworkService.shared.fetchURL(fullURL)
        let result = Parser.parseSearchResults(from: html)

        await MainActor.run {
          searchResults = result.messages
          nextURL = result.nextURL
          prevURL = result.prevURL
          latestURL = result.latestURL
          currentPage = page
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }
}

struct SearchTipRow: View {
  let prefix: String
  let description: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text(prefix)
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(.accentColor)
        .frame(width: 40, alignment: .leading)
      Text(description)
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
  }
}

struct MessageRowView: View {
  let message: Message
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(message.subject)
        .font(.system(size: 13, weight: .medium))
        .lineLimit(2)
        .foregroundColor(isSelected ? .white : .primary)

      HStack(spacing: 8) {
        Text(formatDate(message.timestamp))
          .font(.system(size: 11))
          .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

        if let messageId = message.messageId.split(separator: "/").dropLast().last {
          Text(String(messageId))
            .font(.system(size: 11))
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isSelected ? Color.accentColor : Color.clear)
    .cornerRadius(6)
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
