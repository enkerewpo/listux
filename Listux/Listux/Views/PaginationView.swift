import SwiftUI

struct PaginationView: View {
  let currentPage: Int
  let hasNext: Bool
  let hasPrev: Bool
  let hasLatest: Bool
  let onPrev: () -> Void
  let onNext: () -> Void
  let onLatest: () -> Void

  var body: some View {
    HStack(spacing: 24) {
      PaginationButton(
        systemName: "chevron.left",
        help: "Prev (Newer)",
        isEnabled: hasPrev
      ) {
        onPrev()
      }

      PaginationButton(
        systemName: "arrow.left.to.line",
        help: "First Page",
        isEnabled: hasLatest
      ) {
        onLatest()
      }

      Text("Page \(currentPage)")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(minWidth: 60)
        .transition(AnimationConstants.fadeInOut)
        .animation(Animation.userPreferenceQuick, value: currentPage)

      PaginationButton(
        systemName: "chevron.right",
        help: "Next (Older)",
        isEnabled: hasNext
      ) {
        onNext()
      }
    }
    .padding(.trailing, 16)
    .transition(AnimationConstants.slideFromTop)
  }
}

struct PaginationButton: View {
  let systemName: String
  let help: String
  let isEnabled: Bool
  let action: () -> Void

  @State private var isHovered: Bool = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .imageScale(.large)
        .foregroundColor(isEnabled ? (isHovered ? .accentColor : .primary) : .secondary)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .help(help)
    }
    .buttonStyle(.borderless)
    .disabled(!isEnabled)
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isHovered)
  }
} 