import SwiftUI

struct MailingListItemView: View {
  let list: MailingList
  let isSelected: Bool
  let isPinned: Bool
  let onSelect: () -> Void
  let onPinToggle: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    HStack(spacing: 8) {
      // Pin indicator
      if isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 10))
          .foregroundColor(.orange)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(list.name)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(1)
        Text(list.desc)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()

      // Pin toggle button
      Button(action: onPinToggle) {
        Image(systemName: isPinned ? "pin.fill" : "pin")
          .font(.system(size: 11))
          .foregroundColor(isPinned ? .orange : .secondary)
          .scaleEffect(isPinned ? AnimationConstants.favoriteScale : 1.0)
      }
      .buttonStyle(.plain)
      .animation(AnimationConstants.springQuick, value: isPinned)
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
