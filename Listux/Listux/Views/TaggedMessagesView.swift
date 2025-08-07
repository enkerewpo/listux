import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct TaggedMessageRowView: View {
  let message: Message
  let preference: Preference
  @Binding var selectedMessage: Message?
  @State private var isHovered: Bool = false
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(message.subject)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)

          HStack {
            Text(message.mailingList?.name ?? "Unknown")
              .font(.system(size: 10))
              .foregroundColor(.secondary)

            Spacer()

            Text(message.timestamp, style: .date)
              .font(.system(size: 8))
              .foregroundColor(.secondary)
          }

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
                UIPasteboard.general.string = message.messageId
              #endif
            }) {
              Image(systemName: "doc.on.doc")
                #if os(macOS)
                  .font(.system(size: 10))
                #else
                  .font(.system(size: 12))
                #endif
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy Message ID")
          }
        }

        Spacer()

        HStack(spacing: 4) {
          // Only show tags for favorited messages
          if favoriteMessageService.getFavoriteMessage(messageId: message.messageId) != nil {
            ForEach(favoriteMessageService.getTags(for: message.messageId), id: \.self) { tag in
              TagChipView(tag: tag) {
                favoriteMessageService.removeTag(tag, from: message.messageId)
              }
            }

            Button(action: {
              showingTagInput = true
            }) {
              Image(systemName: "plus.circle")
                #if os(macOS)
                  .font(.system(size: 14))
                #else
                  .font(.system(size: 16))
                #endif
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
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
          }

          Button(action: {
            withAnimation(Animation.userPreferenceQuick) {
              favoriteMessageService.toggleFavorite(message)
            }
          }) {
            Image(systemName: "star.fill")
              #if os(macOS)
                .font(.system(size: 14))
              #else
                .font(.system(size: 16))
              #endif
              .foregroundColor(.yellow)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 3)
        .fill(
          selectedMessage?.messageId == message.messageId
            ? Color.accentColor.opacity(0.1)
            : (isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
    )
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isHovered)
    .animation(
      Animation.userPreferenceQuick, value: selectedMessage?.messageId == message.messageId
    )
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
}

struct TagChipView: View {
  let tag: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 2) {
      Text(tag)
        #if os(macOS)
          .font(.system(size: 10))
        #else
          .font(.system(size: 12))
        #endif
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue.opacity(0.2))
        )

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          #if os(macOS)
            .font(.system(size: 10))
          #else
            .font(.system(size: 12))
          #endif
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
    }
  }
}

struct TaggedMessagesView: View {
  let tag: String
  let messages: [Message]
  @Binding var selectedMessage: Message?
  let preference: Preference
  @Environment(\.modelContext) private var modelContext
  @State private var favoriteMessageService = FavoriteMessageService.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Tag: \(tag)")
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()
        Text("\(messages.count) message\(messages.count == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      #if os(macOS)
        .background(Color(.windowBackgroundColor).opacity(0.95))
      #else
        .background(Color(.systemGroupedBackground))
      #endif

      Divider()

      if messages.isEmpty {
        Text("No messages with tag '\(tag)'")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedMessage) {
          ForEach(messages, id: \.messageId) { message in
            TaggedMessageRowView(
              message: message, preference: preference, selectedMessage: $selectedMessage
            )
            .onTapGesture {
              withAnimation(Animation.userPreferenceQuick) {
                selectedMessage = message
              }
            }
          }
        }
        #if os(macOS)
          .listStyle(.inset)
        #else
          .listStyle(.insetGrouped)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct TagItemView: View {
  let tag: String
  let isSelected: Bool
  let messageCount: Int
  let onSelect: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: tag == "Untagged" ? "tag.slash" : "tag")
        .font(.system(size: 12))
        .foregroundColor(
          isSelected
            ? .white
            : (tag == "Untagged" ? .secondary : .blue)
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(tag)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(isSelected ? .white : .primary)
          .lineLimit(1)
        Text("\(messageCount) message\(messageCount == 1 ? "" : "s")")
          .font(.system(size: 11))
          .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(
          isSelected
            ? Color.blue.opacity(0.3)
            : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
    )
    .onTapGesture(perform: onSelect)
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isSelected)
    .animation(Animation.userPreferenceQuick, value: isHovered)
  }
}
