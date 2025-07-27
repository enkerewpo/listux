import SwiftUI
import SwiftData

struct MessageListView: View {
  var selectedSidebarTab: SidebarTab
  var selectedList: MailingList?
  @Binding var selectedMessage: Message?
  var isLoading: Bool
  /// URL for the next (older) page, if available
  var nextURL: String?
  /// URL for the previous (newer) page, if available
  var prevURL: String?
  /// URL for the latest page, if available
  var latestURL: String?
  /// Current page number
  var currentPage: Int = 1
  /// Callback when a pagination button is tapped
  var onPageLinkTapped: ((String) -> Void)?
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
    ZStack {
      VStack(spacing: 0) {
        // Main message list
        if let list = selectedList, selectedSidebarTab == .lists {
          let rootMessages = list.orderedMessages.filter { $0.parent == nil }
          List(selection: $selectedMessage) {
            if list.orderedMessages.isEmpty {
              Text("No messages loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnimationConstants.fadeInOut)
            } else if rootMessages.isEmpty {
              Text("No root messages found (all messages have parents)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnimationConstants.fadeInOut)
            } else {
              ForEach(rootMessages.sorted { $0.seqId < $1.seqId }) { message in
                MessageRowView(
                  message: message, 
                  depth: 0, 
                  selectedMessage: $selectedMessage,
                  preference: preference
                )
                  .transition(AnimationConstants.slideFromLeading)
              }
            }
          }
          .listStyle(.inset)
          .frame(maxWidth: .infinity)
          .animation(AnimationConstants.standard, value: list.orderedMessages.count)
        } else {
          Text("Select a list to view messages")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(AnimationConstants.fadeInOut)
        }
      }
      // Overlay loading indicator
      if isLoading {
        Color.black.opacity(0.1)
          .ignoresSafeArea()
          .transition(.opacity)
        ProgressView("Loading messages...")
          .padding(32)
          #if os(macOS)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
          #else
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
          #endif
          .shadow(radius: 8)
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.8)),
              removal: .opacity.combined(with: .scale(scale: 1.1))
            ))
      }
    }
    .animation(AnimationConstants.standard, value: isLoading)
  }
}

struct MessageRowView: View {
  let message: Message
  let depth: Int
  @Binding var selectedMessage: Message?
  let preference: Preference
  @State private var isHovered: Bool = false
  
  private var isFavorite: Bool {
    preference.isFavoriteMessage(message.messageId)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Main message row
      HStack(alignment: .center, spacing: 0) {
        // Indentation for hierarchy
        HStack(spacing: 4) {
          ForEach(0..<min(depth, 6), id: \.self) { _ in
            Rectangle()
              .fill(Color.secondary.opacity(0.3))
              .frame(width: 2)
              .transition(.opacity.combined(with: .scale(scale: 0.8)))
          }
        }

        // Expand/collapse button for messages with replies
        if !message.replies.isEmpty {
          Button(action: {
            withAnimation(AnimationConstants.standard) {
              message.isExpanded.toggle()
            }
          }) {
            Image(systemName: message.isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
              .rotationEffect(.degrees(message.isExpanded ? 90 : 0))
              .animation(AnimationConstants.quick, value: message.isExpanded)
          }
          .buttonStyle(.plain)
        } else {
          // Empty space for alignment when no replies
          Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
        }

        // Message content
        HStack(alignment: .center, spacing: 4) {
          VStack(alignment: .leading, spacing: 2) {
            Text(message.subject)
              .font(.system(size: 12, weight: .regular))
            
            // Message ID with copy functionality
            HStack {
              Text("ID: \(message.messageId)")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
              
              Spacer()
              
              Button(action: {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.messageId, forType: .string)
                #else
                // TODO: Implement copy to clipboard for iOS
                #endif
              }) {
                Image(systemName: "doc.on.doc")
                  .font(.system(size: 8))
                  .foregroundColor(.blue)
              }
              .buttonStyle(.plain)
              .help("Copy Message ID")
            }
          }

          Spacer(minLength: 8)

          Text(message.timestamp, style: .date)
            .font(.system(size: 8))
            .foregroundColor(.secondary)
        }

        Spacer()

        // Favorite button
        Button(action: {
          withAnimation(AnimationConstants.springQuick) {
            preference.toggleFavoriteMessage(message.messageId)
          }
        }) {
          Image(systemName: isFavorite ? "star.fill" : "star")
            .foregroundColor(isFavorite ? .yellow : .secondary)
            .scaleEffect(isFavorite ? AnimationConstants.favoriteScale : 1.0)
        }
        .buttonStyle(.plain)
        .animation(AnimationConstants.springQuick, value: isFavorite)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(selectedMessage?.id == message.id ? Color.accentColor.opacity(0.1) : Color.clear)
          .scaleEffect(isHovered ? AnimationConstants.selectedScale : 1.0)
      )
      .onTapGesture {
        withAnimation(AnimationConstants.quick) {
          selectedMessage = message
        }
      }
      .onHover { hovering in
        withAnimation(AnimationConstants.quick) {
          isHovered = hovering
        }
      }
      .animation(AnimationConstants.quick, value: selectedMessage?.id == message.id)
      .frame(maxWidth: .infinity, alignment: .leading)

      // Child messages (replies)
      if message.isExpanded && !message.replies.isEmpty {
        ForEach(message.replies.sorted { $0.seqId < $1.seqId }) { reply in
          MessageRowView(
            message: reply, 
            depth: depth + 1, 
            selectedMessage: $selectedMessage,
            preference: preference
          )
            .padding(.leading, CGFloat(min(depth + 1, 6)) * 16)
            .transition(AnimationConstants.slideFromLeading)
        }
      }
    }
  }
}

#Preview {
  MessageListView(
    selectedSidebarTab: .lists, selectedList: nil, selectedMessage: .constant(nil),
    isLoading: false,
    nextURL: nil, prevURL: nil, latestURL: nil, onPageLinkTapped: nil
  )
}
