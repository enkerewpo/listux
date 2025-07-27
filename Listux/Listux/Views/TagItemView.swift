import SwiftUI

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
        .foregroundColor(tag == "Untagged" ? .secondary : .blue)

      VStack(alignment: .leading, spacing: 2) {
        Text(tag)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(1)
        Text("\(messageCount) message\(messageCount == 1 ? "" : "s")")
          .font(.system(size: 11))
          .foregroundColor(.secondary)
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
            ? Color.accentColor.opacity(0.15)
            : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
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
