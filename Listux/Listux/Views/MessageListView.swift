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
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @State private var isLoadingMore: Bool = false
  @State private var hasReachedEnd: Bool = false
  @State private var scrollViewHeight: CGFloat = 0
  @State private var contentHeight: CGFloat = 0

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
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
        NavigationLink(destination: MessageDetailView(selectedMessage: message)) {
          CompactMessageRowView(message: message, preference: preference)
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
  
  private var contentGeometryReader: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear {
          contentHeight = geometry.size.height
        }
        .onChange(of: geometry.size.height) { _, newHeight in
          contentHeight = newHeight
        }
    }
  }
  
  private var scrollViewGeometryReader: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear {
          scrollViewHeight = geometry.size.height
        }
        .onChange(of: geometry.size.height) { _, newHeight in
          scrollViewHeight = newHeight
        }
    }
  }
  
  private var loadingOverlay: some View {
    Group {
      if isLoading && messages.isEmpty {
        ProgressView("Loading...")
      }
    }
  }
  
  var body: some View {
    let sortedMessages = self.sortedMessages
    let messageCount = messages.count
    let title = self.title
    
    print("MessageListView body recalculated for '\(title)' with \(messageCount) messages")
    
    return ScrollView {
      messageListContent
        .background(contentGeometryReader)
    }
    .background(scrollViewGeometryReader)
    .onChange(of: contentHeight) { _, _ in
      checkForAutoLoad()
    }
    .onChange(of: scrollViewHeight) { _, _ in
      checkForAutoLoad()
    }
    .navigationTitle(title)
    .overlay(loadingOverlay)
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
  
  private func checkForAutoLoad() {
    // 当内容高度接近滚动视图高度时触发加载更多
    if contentHeight > scrollViewHeight * 0.7 && !isLoadingMore && !hasReachedEnd {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        loadMoreMessages()
      }
    }
  }
  
  private func loadMoreMessages() {
    guard let onLoadMore = onLoadMore, !isLoadingMore, !hasReachedEnd else {
      return
    }
    
    isLoadingMore = true
    print("触发加载更多消息")
    
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
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""
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
        }
        
        Button(action: {
          showingTagInput = true
        }) {
          Image(systemName: "plus.circle")
            .font(.system(size: 10))
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .popover(isPresented: $showingTagInput) {
          VStack(spacing: 8) {
            Text("Add Tag")
              .font(.headline)

            TextField("Tag name", text: $newTag)
              .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
              Button("Cancel") {
                showingTagInput = false
                newTag = ""
              }

              Button("Add") {
                if !newTag.isEmpty {
                  favoriteMessageService.addTag(newTag, to: message.messageId)
                  if !message.tags.contains(newTag) {
                    message.tags.append(newTag)
                  }
                  newTag = ""
                }
                showingTagInput = false
              }
              .disabled(newTag.isEmpty)
            }
          }
          .padding()
          .frame(width: 200)
        }
        #else
        .sheet(isPresented: $showingTagInput) {
          NavigationView {
            VStack(spacing: 8) {
              Text("Add Tag")
                .font(.headline)

              TextField("Tag name", text: $newTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())

              HStack {
                Button("Cancel") {
                  showingTagInput = false
                  newTag = ""
                }

                Button("Add") {
                  if !newTag.isEmpty {
                    favoriteMessageService.addTag(newTag, to: message.messageId)
                    if !message.tags.contains(newTag) {
                      message.tags.append(newTag)
                    }
                    newTag = ""
                  }
                  showingTagInput = false
                }
                .disabled(newTag.isEmpty)
              }
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
              showingTagInput = false
            })
          }
        }
        #endif
        
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
          isHovered 
            ? Color.accentColor.opacity(0.1)
            : Color.clear
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isHovered 
                ? Color.accentColor.opacity(0.3)
                : Color.clear,
              lineWidth: 1
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

