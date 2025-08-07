import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

#if os(macOS)
  import AppKit
#endif

struct MessageListView: View {
  let messages: [Message]
  let title: String
  let isLoading: Bool
  let onLoadMore: (() async -> Void)?
  let hasReachedEnd: Bool
  @Binding var selectedMessage: Message?
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @State private var isLoadingMore: Bool = false
  @State private var lastMessageIdBeforeLoad: String? = nil

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

  // Sort messages by seqId to maintain stable order
  private var sortedMessages: [Message] {
    let sorted = messages.sorted { $0.seqId < $1.seqId }
    print("MessageListView sortedMessages recalculated: \(sorted.count) messages")
    for (index, message) in sorted.enumerated() {
      print("  [\(index)] SeqID: \(message.seqId), Subject: \(message.subject)")
    }
    return sorted
  }

  private func alternatingRowColor(for index: Int) -> Color {
    if index % 2 == 0 {
      return Color.clear
    } else {
      return Color.gray.opacity(0.15)
    }
  }

  private var messageListContent: some View {
    LazyVStack(spacing: 0) {
      // Show initial state message when no messages
      if messages.isEmpty && !isLoading {
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
        ForEach(Array(sortedMessages.enumerated()), id: \.element.messageId) { index, message in
          Button(action: {
            print("MessageListView: Button tapped for message: \(message.subject)")
            withAnimation(AnimationConstants.quick) {
              selectedMessage = message
            }
          }) {
            CompactMessageRowView(
              message: message, preference: preference,
              isSelected: selectedMessage?.messageId == message.messageId)
          }
          .buttonStyle(PlainButtonStyle())
          .background(
            Rectangle()
              .fill(alternatingRowColor(for: index))
              .opacity(0.3)
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

        // Load Next Page button - subtle and always show
        if !messages.isEmpty {
          Button(action: {
            print("MessageListView: Load Next Page button tapped")
            // Record the last message ID before loading
            if let lastMessage = sortedMessages.last {
              lastMessageIdBeforeLoad = lastMessage.messageId
              print("MessageListView: Recording last message ID: \(lastMessage.messageId)")
              print("MessageListView: Last message subject: \(lastMessage.subject)")
            } else {
              print("MessageListView: No last message found")
            }
            loadMoreMessages()
          }) {
            HStack(spacing: 6) {
              Image(systemName: "arrow.down")
                .font(.system(size: 12))
              Text("Load Next Page")
                .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
            )
          }
          .buttonStyle(.plain)
          .padding(.top, 8)
          .padding(.bottom, 16)
          .disabled(isLoadingMore)
          .opacity(isLoadingMore ? 0.5 : 1.0)
          .onAppear {
            print("MessageListView: Load Next Page button appeared!")
          }
        }
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 8)
    #if os(iOS)
      .padding(.top, 0)
    #endif
  }

  var body: some View {
    let messageCount = messages.count
    let title = self.title

    print(
      "MessageListView body recalculated for '\(title)' with \(messageCount) messages, onLoadMore: \(onLoadMore != nil)"
    )

    return ScrollViewReader { proxy in
      ScrollView {
        messageListContent
      }
      .onChange(of: messages.count) { oldCount, newCount in
        // When new messages are added, scroll to the last message from previous page
        if newCount > oldCount, let lastMessageId = lastMessageIdBeforeLoad {
          print("MessageListView: Scrolling to last message from previous page: \(lastMessageId)")
          print("MessageListView: Old count: \(oldCount), New count: \(newCount)")
          print(
            "MessageListView: Current messages: \(sortedMessages.map { $0.messageId }.suffix(5))")

          // Wait longer for UI to update completely
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("MessageListView: Attempting to scroll to: \(lastMessageId)")
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
          }
          lastMessageIdBeforeLoad = nil
        } else if newCount > oldCount {
          print("MessageListView: New messages added but no lastMessageId recorded")
        }
      }
    }
    #if os(iOS)
      .scrollContentBackground(.hidden)
      .scrollIndicators(.hidden)
    #endif
    .navigationTitle(title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .overlay(
      Group {
        if isLoading && messages.isEmpty {
          ProgressView("Loading...")
        }
      }
    )
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }

  private func loadMoreMessages() {
    print("MessageListView: loadMoreMessages called")
    print("MessageListView: onLoadMore is \(onLoadMore != nil ? "available" : "nil")")
    guard let onLoadMore = onLoadMore else {
      print("MessageListView: No onLoadMore callback available")
      return
    }

    if isLoadingMore {
      print("MessageListView: Already loading more messages")
      return
    }

    isLoadingMore = true
    print("MessageListView: Triggering load more messages")

    Task {
      await onLoadMore()
      await MainActor.run {
        isLoadingMore = false
        print("MessageListView: loadMoreMessages completed")
      }
    }
  }
}

struct CompactMessageRowView: View {
  @ObservedObject var message: Message
  let preference: Preference
  let isSelected: Bool
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext
  @State private var isHovered: Bool = false

  private var isFavorite: Bool {
    message.isFavorite
  }

  var body: some View {
    HStack(alignment: .center, spacing: 6) {
      // Debug seqId - always visible with proper width
      Text("#\(message.seqId)")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.primary)
        .frame(width: 30, alignment: .leading)
        .lineLimit(1)

      // 左边：标题
      Text(message.subject)
        .font(.system(size: 12))
        .lineLimit(1)
        .truncationMode(.tail)
        .foregroundColor(.primary)
        .opacity(isSelected ? 1.0 : 0.8)

      Spacer()

      // 右边：工具按钮
      HStack(spacing: 4) {
        if isFavorite {
          ForEach(message.tags, id: \.self) { tag in
            TagChipView(tag: tag) {
              favoriteMessageService.removeTag(tag, from: message.messageId)
              message.tags.removeAll { $0 == tag }
            }
          }

          TagAddButton(messageId: message.messageId)
        }

        Button(action: {
          withAnimation(AnimationConstants.quick) {
            favoriteMessageService.toggleFavorite(message)
          }
        }) {
          Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: 10))
            .foregroundColor(isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.2)
            : (isHovered
              ? Color.accentColor.opacity(0.1)
              : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isSelected
                ? Color.accentColor.opacity(0.6)
                : (isHovered
                  ? Color.accentColor.opacity(0.3)
                  : Color.clear),
              lineWidth: isSelected ? 2 : 1
            )
        )
    )
    #if os(macOS)
      .onHover { hovering in
        withAnimation(AnimationConstants.quick) {
          isHovered = hovering
        }
      }
    #endif
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
}
