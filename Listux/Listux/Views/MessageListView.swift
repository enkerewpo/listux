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
  @Binding var selectedMessage: Message?
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @State private var isLoadingMore: Bool = false
  @State private var hasReachedEnd: Bool = false
  @State private var scrollOffset: CGFloat = 0
  @State private var contentHeight: CGFloat = 0
  @State private var scrollViewHeight: CGFloat = 0

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
    }
    .padding(.leading, 8)
    .padding(.trailing, 8)
    #if os(iOS)
      .padding(.top, 0)
    #endif
  }

  var body: some View {
    let sortedMessages = self.sortedMessages
    let messageCount = messages.count
    let title = self.title

    print("MessageListView body recalculated for '\(title)' with \(messageCount) messages")

    return ScrollView {
      messageListContent
        .background(
          GeometryReader { contentGeometry in
            Color.clear
              .onAppear {
                contentHeight = contentGeometry.size.height
              }
              .onChange(of: contentGeometry.size.height) { _, newHeight in
                contentHeight = newHeight
              }
          }
        )
    }
    #if os(iOS)
      .scrollContentBackground(.hidden)
      .scrollIndicators(.hidden)
    #endif
    .background(
      GeometryReader { scrollGeometry in
        Color.clear
          .onAppear {
            scrollViewHeight = scrollGeometry.size.height
          }
          .onChange(of: scrollGeometry.size.height) { _, newHeight in
            scrollViewHeight = newHeight
          }
      }
    )
    .onChange(of: contentHeight) { _, _ in
      checkForAutoLoad()
    }
    .onChange(of: scrollViewHeight) { _, _ in
      checkForAutoLoad()
    }
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

  private func checkForAutoLoad() {
    // Only check if we have an onLoadMore function and we're not already loading
    guard let onLoadMore = onLoadMore, !isLoadingMore, !hasReachedEnd else {
      return
    }

    // Check if content height is greater than scroll view height (indicating scrollable content)
    // and if we're close to the bottom (within 100 points)
    let scrollableContent = contentHeight - scrollViewHeight
    if scrollableContent > 0 && scrollableContent < 100 {
      print(
        "MessageListView: Triggering auto-load - contentHeight: \(contentHeight), scrollViewHeight: \(scrollViewHeight)"
      )
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        loadMoreMessages()
      }
    }
  }

  private func loadMoreMessages() {
    guard let onLoadMore = onLoadMore, !isLoadingMore, !hasReachedEnd else {
      print(
        "MessageListView: Skipping loadMoreMessages - onLoadMore: \(onLoadMore != nil), isLoadingMore: \(isLoadingMore), hasReachedEnd: \(hasReachedEnd)"
      )
      return
    }

    isLoadingMore = true
    print("MessageListView: Triggering load more messages")

    Task {
      await onLoadMore()
      await MainActor.run {
        isLoadingMore = false
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
    HStack(alignment: .center, spacing: 8) {
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
