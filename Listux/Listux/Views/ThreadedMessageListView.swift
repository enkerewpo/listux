import SwiftData
import SwiftUI

struct ThreadedMessageListView: View {
  let rootMessages: [Message]
  let title: String
  let isLoading: Bool
  let onLoadMore: (() async -> Void)?
  let hasReachedEnd: Bool
  @Binding var selectedMessage: Message?
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @State private var isLoadingMore: Bool = false
  @State private var expandedMessages: Set<String> = Set() // Track expanded messages by messageId
  
  // Pagination state
  @State private var currentPage: Int = 1
  @State private var totalPages: Int = 1
  @State private var showPageInfo: Bool = false

  // Pagination URL state
  let nextURL: String?
  let prevURL: String?
  let latestURL: String?
  let onLoadPrev: (() async -> Void)?
  let onLoadLatest: (() async -> Void)?
  @Binding var pageNumber: Int

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      try? modelContext.save()
      return new
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Pagination toolbar
      if !rootMessages.isEmpty && showPageInfo {
        VStack(spacing: 0) {
          Divider()
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
              Text("Page \(pageNumber)")
                .font(.system(size: 13, weight: .medium))
              if totalPages > 1 {
                Text("of \(totalPages)")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
            }
            .frame(minWidth: 60)

            Spacer()

            HStack(spacing: 4) {
              Text("\(rootMessages.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
              Image(systemName: "envelope")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
              if prevURL != nil && onLoadPrev != nil {
                Button(action: { loadPrevMessages() }) {
                  Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                      RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
              }

              if latestURL != nil && onLoadLatest != nil {
                Button(action: { loadLatestMessages() }) {
                  HStack(spacing: 4) {
                    Image(systemName: "arrow.up.to.line")
                      .font(.system(size: 11, weight: .medium))
                    Text("Latest")
                      .font(.system(size: 11, weight: .medium))
                  }
                  .foregroundColor(.orange)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color.orange.opacity(0.1))
                  )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
              }

              if !hasReachedEnd {
                Button(action: { loadMoreMessages() }) {
                  Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                      RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
              }
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          Divider()
        }
      }

      // Message list content
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            if rootMessages.isEmpty && !isLoading {
              VStack(spacing: 12) {
                Image(systemName: "list.bullet")
                  .font(.system(size: 24))
                  .foregroundColor(.secondary)
                Text("Please select a mailing list")
                  .font(.system(size: 14))
                  .foregroundColor(.secondary)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .padding(.top, 40)
            } else {
              ForEach(rootMessages, id: \.messageId) { rootMessage in
                ThreadedMessageRowView(
                  message: rootMessage,
                  level: 0,
                  preference: preference,
                  selectedMessage: $selectedMessage,
                  expandedMessages: $expandedMessages
                )
              }

              if isLoadingMore {
                HStack {
                  Spacer()
                  ProgressView("Loading more...")
                    .padding()
                  Spacer()
                }
              }
            }
          }
          .padding(.horizontal, 8)
        }
      }
    }
    .navigationTitle(title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .overlay(
      Group {
        if isLoading && rootMessages.isEmpty {
          ProgressView("Loading...")
        }
      }
    )
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
      updatePaginationInfo()
      // Expand all root messages by default
      for message in rootMessages {
        expandedMessages.insert(message.messageId)
      }
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
      updatePaginationInfo()
    }
  }

  private func loadMoreMessages() {
    guard let onLoadMore = onLoadMore, !isLoadingMore else { return }
    isLoadingMore = true
    Task {
      await onLoadMore()
      await MainActor.run {
        isLoadingMore = false
      }
    }
  }

  private func loadPrevMessages() {
    guard let onLoadPrev = onLoadPrev, !isLoadingMore else { return }
    isLoadingMore = true
    Task {
      await onLoadPrev()
      await MainActor.run {
        isLoadingMore = false
      }
    }
  }

  private func loadLatestMessages() {
    guard let onLoadLatest = onLoadLatest, !isLoadingMore else { return }
    isLoadingMore = true
    Task {
      await onLoadLatest()
      await MainActor.run {
        isLoadingMore = false
      }
    }
  }

  private func updatePaginationInfo() {
    withAnimation(.easeInOut(duration: 0.3)) {
      showPageInfo = rootMessages.count > 0
    }
  }
}

struct ThreadedMessageRowView: View {
  let message: Message
  let level: Int
  let preference: Preference
  @Binding var selectedMessage: Message?
  @Binding var expandedMessages: Set<String>
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext
  @State private var isHovered: Bool = false

  private var isExpanded: Bool {
    expandedMessages.contains(message.messageId)
  }

  private var isSelected: Bool {
    selectedMessage?.messageId == message.messageId
  }

  private var isFavorite: Bool {
    message.isFavorite
  }

  private var hasReplies: Bool {
    !message.replies.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: {
        withAnimation(AnimationConstants.quick) {
          selectedMessage = message
        }
      }) {
        HStack(alignment: .center, spacing: 6) {
          // Indentation for nesting level
          if level > 0 {
            HStack(spacing: 0) {
              ForEach(0..<level, id: \.self) { _ in
                Rectangle()
                  .fill(Color.secondary.opacity(0.2))
                  .frame(width: 1)
                  .padding(.leading, 8)
              }
            }
          }

          // Expand/collapse button for messages with replies
          if hasReplies {
            Button(action: {
              withAnimation(AnimationConstants.quick) {
                if isExpanded {
                  expandedMessages.remove(message.messageId)
                } else {
                  expandedMessages.insert(message.messageId)
                }
              }
            }) {
              Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
          } else {
            // Spacer for alignment when no expand button
            Spacer()
              .frame(width: 12)
          }

          // Message number
          Text("#\(message.seqId)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 30, alignment: .leading)
            .lineLimit(1)

          // Subject
          Text(message.subject)
            .font(.system(size: 12))
            .lineLimit(1)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          // Favorite star
          Button(action: {
            withAnimation(AnimationConstants.quick) {
              favoriteMessageService.toggleFavorite(message)
            }
          }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
              .font(.system(size: 12))
              .foregroundColor(isFavorite ? .yellow : .secondary)
          }
          .buttonStyle(.plain)
          .frame(width: 20)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(
              isSelected
                ? Color.accentColor.opacity(0.15)
                : (isHovered
                  ? Color.accentColor.opacity(0.08)
                  : Color.clear)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(
                  isSelected
                    ? Color.accentColor.opacity(0.5)
                    : Color.clear,
                  lineWidth: isSelected ? 1 : 0
                )
            )
        )
      }
      .buttonStyle(.plain)
      #if os(macOS)
        .onHover { hovering in
          withAnimation(AnimationConstants.quick) {
            isHovered = hovering
          }
        }
      #endif

      // Only render first-level replies (level 0 = root, level 1 = first level replies)
      // Do not render deeper levels to match HTML behavior
      if isExpanded && hasReplies && level < 1 {
        ForEach(message.replies, id: \.messageId) { reply in
          ThreadedMessageRowView(
            message: reply,
            level: level + 1,
            preference: preference,
            selectedMessage: $selectedMessage,
            expandedMessages: $expandedMessages
          )
        }
      }
    }
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
}
