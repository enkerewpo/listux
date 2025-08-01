import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct MessageListView: View {
  let messages: [Message]
  let title: String
  let isLoading: Bool
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
    List(messages, id: \.messageId) { message in
      NavigationLink(destination: MessageDetailView(selectedMessage: message)) {
        SimpleMessageRowView(message: message, preference: preference)
      }
    }
    .navigationTitle(title)
    .overlay(
      Group {
        if isLoading {
          ProgressView("Loading...")
        }
      }
    )
  }
}

struct SimpleMessageRowView: View {
  let message: Message
  let preference: Preference
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""

  private var isFavorite: Bool {
    preference.isFavoriteMessage(message.messageId)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(message.subject)
            .font(.headline)

          HStack {
            Text(message.timestamp, style: .date)
              .font(.caption)
              .foregroundColor(.secondary)

            #if os(macOS)
              Spacer()

              Text("ID: \(message.messageId)")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            #endif
          }

          #if os(macOS)
            HStack {
              Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.messageId, forType: .string)
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

              Spacer()
            }
          #else
            // iOS clipboard implementation
            HStack {
              Button(action: {
                UIPasteboard.general.string = message.messageId
              }) {
                Image(systemName: "doc.on.doc")
                  .font(.system(size: 12))
                  .foregroundColor(.blue)
              }
              .buttonStyle(.plain)
              .help("Copy Message ID")
            }
          #endif
        }

        Spacer()

        HStack(spacing: 4) {
          #if os(macOS)
            // Only show tags for favorited messages on macOS
            if isFavorite {
              ForEach(preference.getTags(for: message.messageId), id: \.self) { tag in
                TagChipView(tag: tag) {
                  preference.removeTag(tag, from: message.messageId)
                }
              }
            }
          #endif

          // Only show add tag button for favorited messages
          if isFavorite {
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
                      preference.addTag(newTag, to: message.messageId)
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
              preference.toggleFavoriteMessage(message.messageId)
            }
          }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
              #if os(macOS)
                .font(.system(size: 14))
              #else
                .font(.system(size: 16))
              #endif
                .foregroundColor(isFavorite ? .yellow : .secondary)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

