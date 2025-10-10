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
  
  // 分页状态
  @State private var currentPage: Int = 1
  @State private var totalPages: Int = 1
  @State private var pageSize: Int = 50
  @State private var showPageInfo: Bool = false
  
  // 分页URL状态 - 从外部传入
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
    LazyVStack(spacing: 2) { // 减少间距以容纳两行标题
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

    return VStack(spacing: 0) {
      // 固定的分页工具栏
      if !messages.isEmpty && showPageInfo {
        VStack(spacing: 0) {
          Divider()
          
          // 分页导航
          HStack(spacing: 12) {
            // 页码信息
            VStack(alignment: .leading, spacing: 1) {
              Text("Page \(pageNumber)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
              
              if totalPages > 1 {
                Text("of \(totalPages)")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
            }
            .frame(minWidth: 60)
            
            Spacer()
            
            // 消息计数
            HStack(spacing: 4) {
              Text("\(messages.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              
              Image(systemName: "envelope")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            // 分页控制按钮
            HStack(spacing: 8) {
              // 向前导航按钮
              if prevURL != nil && onLoadPrev != nil {
                Button(action: {
                  loadPrevMessages()
                }) {
                  HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                      .font(.system(size: 11, weight: .medium))
                    // Text("Previous")
                    //   .font(.system(size: 11, weight: .medium))
                    //   .lineLimit(1)
                    //   .minimumScaleFactor(0.8)
                  }
                  .foregroundColor(.accentColor)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 6)
                  // .frame(minWidth: 70)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color.accentColor.opacity(0.1))
                  )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
                .opacity(isLoadingMore ? 0.5 : 1.0)
                #if os(macOS)
                .onHover { hovering in
                  // macOS hover effect
                }
                #endif
              }
              
              // 跳转到最新页面按钮
              if latestURL != nil && onLoadLatest != nil {
                Button(action: {
                  loadLatestMessages()
                }) {
                  HStack(spacing: 4) {
                    Image(systemName: "arrow.up.to.line")
                      .font(.system(size: 11, weight: .medium))
                    Text("Latest")
                      .font(.system(size: 11, weight: .medium))
                      .lineLimit(1)
                      .minimumScaleFactor(0.8)
                  }
                  .foregroundColor(.orange)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .frame(minWidth: 70)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color.orange.opacity(0.1))
                  )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
                .opacity(isLoadingMore ? 0.5 : 1.0)
                #if os(macOS)
                .onHover { hovering in
                  // macOS hover effect
                }
                #endif
              }
              
              // 向后导航按钮
              if !hasReachedEnd {
                Button(action: {
                  loadMoreMessages()
                }) {
                  HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                      .font(.system(size: 11, weight: .medium))
                    // Text("Next")
                    //   .font(.system(size: 11, weight: .medium))
                    //   .lineLimit(1)
                    //   .minimumScaleFactor(0.8)
                  }
                  .foregroundColor(.accentColor)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 6)
                  // .frame(minWidth: 70)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color.accentColor.opacity(0.1))
                  )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
                .opacity(isLoadingMore ? 0.5 : 1.0)
                #if os(macOS)
                .onHover { hovering in
                  // macOS hover effect
                }
                #endif
              }
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .background(
            Group {
              #if os(iOS)
                Color(.systemBackground)
              #else
                Color(.windowBackgroundColor)
              #endif
            }
            .opacity(0.8)
          )
          
          Divider()
        }
      }

      // 消息列表内容
      ScrollViewReader { proxy in
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
            
            // 更新分页信息
            updatePaginationInfo()
          } else if newCount > oldCount {
            print("MessageListView: New messages added but no lastMessageId recorded")
            updatePaginationInfo()
          }
        }
      }
      #if os(iOS)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
      #endif
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
      updatePaginationInfo()
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
      updatePaginationInfo()
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
  
  private func loadPrevMessages() {
    print("MessageListView: loadPrevMessages called")
    print("MessageListView: onLoadPrev is \(onLoadPrev != nil ? "available" : "nil")")
    guard let onLoadPrev = onLoadPrev else {
      print("MessageListView: No onLoadPrev callback available")
      return
    }

    if isLoadingMore {
      print("MessageListView: Already loading messages")
      return
    }

    isLoadingMore = true
    print("MessageListView: Triggering load previous messages")

    Task {
      await onLoadPrev()
      await MainActor.run {
        isLoadingMore = false
        print("MessageListView: loadPrevMessages completed")
      }
    }
  }
  
  private func loadLatestMessages() {
    print("MessageListView: loadLatestMessages called")
    print("MessageListView: onLoadLatest is \(onLoadLatest != nil ? "available" : "nil")")
    guard let onLoadLatest = onLoadLatest else {
      print("MessageListView: No onLoadLatest callback available")
      return
    }

    if isLoadingMore {
      print("MessageListView: Already loading messages")
      return
    }

    isLoadingMore = true
    print("MessageListView: Triggering load latest messages")

    Task {
      await onLoadLatest()
      await MainActor.run {
        isLoadingMore = false
        print("MessageListView: loadLatestMessages completed")
      }
    }
  }
  
  private func updatePaginationInfo() {
    // 页码应该由外部传入或基于实际的页面导航
    // 这里我们保持当前页码不变，除非有明确的页面变化
    withAnimation(.easeInOut(duration: 0.3)) {
      showPageInfo = messages.count > 0
    }
    
    print("MessageListView: Updated pagination - Current: \(currentPage), Total: \(totalPages), Messages: \(messages.count)")
  }
  
  // 新增方法：更新页码（由外部调用）
  func updatePageNumber(_ newPage: Int, total: Int) {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentPage = newPage
      totalPages = total
      showPageInfo = messages.count > 0
    }
    print("MessageListView: Page updated - Current: \(currentPage), Total: \(totalPages)")
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
  
  private var displayTitle: String {
    if !message.content.isEmpty {
      if let parsedSubject = MessageParsingUtils.extractSubjectFromContent(message.content) {
        return parsedSubject
      }
    }
    return message.subject
  }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      // Debug seqId - always visible with proper width
      Text("#\(message.seqId)")
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.secondary)
        .frame(width: 35, alignment: .leading) // 减少序号区域宽度
        .lineLimit(1)

      // 标题 - 确保完整显示
      Text(displayTitle)
        .font(.system(size: 11))
        .lineLimit(2) // 允许两行显示
        .multilineTextAlignment(.leading)
        .foregroundColor(.primary)
        .opacity(isSelected ? 1.0 : 0.9)
        .frame(maxWidth: .infinity, alignment: .leading) // 占用剩余空间

      // 右边：工具按钮
      HStack(spacing: 6) {
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
            .font(.system(size: 12))
            .foregroundColor(isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
          // macOS hover effect for star button
        }
        #endif
      }
      .frame(minWidth: 50, alignment: .trailing) // 减少工具按钮区域宽度
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 14)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.15)
            : (isHovered
              ? Color.accentColor.opacity(0.08)
              : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isSelected
                ? Color.accentColor.opacity(0.5)
                : (isHovered
                  ? Color.accentColor.opacity(0.2)
                  : Color.clear),
              lineWidth: isSelected ? 1.5 : 0.5
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
