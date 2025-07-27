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
                .font(.system(size: 8))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy Message ID")
          }
        }
        
        Spacer()
        
        HStack(spacing: 4) {
          ForEach(preference.getTags(for: message.messageId), id: \.self) { tag in
            TagChipView(tag: tag) {
              preference.removeTag(tag, from: message.messageId)
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
          
          Button(action: {
            withAnimation(Animation.userPreferenceQuick) {
              preference.toggleFavoriteMessage(message.messageId)
            }
          }) {
            Image(systemName: "star.fill")
              .font(.system(size: 10))
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
    .animation(Animation.userPreferenceQuick, value: selectedMessage?.messageId == message.messageId)
  }
}

struct TagChipView: View {
  let tag: String
  let onRemove: () -> Void
  
  var body: some View {
    HStack(spacing: 2) {
      Text(tag)
        .font(.system(size: 8))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue.opacity(0.2))
        )
      
      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 8))
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
    }
  }
} 