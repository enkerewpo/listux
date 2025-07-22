import SwiftUI

enum SidebarTab: Hashable, CaseIterable {
  case lists, favorites, tags, settings
  var systemImage: String {
    switch self {
    case .lists: return "tray.full"
    case .favorites: return "star"
    case .tags: return "tag"
    case .settings: return "gear"
    }
  }
  var label: String {
    switch self {
    case .lists: return "Lists"
    case .favorites: return "Favorites"
    case .tags: return "Tags"
    case .settings: return "Settings"
    }
  }
}

private struct SidebarTabButton: View {
  let tab: SidebarTab
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    Button(action: action) {
      Image(systemName: tab.systemImage)
        .font(.system(size: 16, weight: .regular))
        .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
        .padding(4)
        .frame(width: 28, height: 28)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .scaleEffect(isHovered ? 1.05 : 1.0)
        )
        .help(tab.label)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .scaleEffect(isHovered ? AnimationConstants.hoverScale : 1.0)
    .animation(Animation.userPreferenceQuick, value: isHovered)
  }
}

struct SidebarView: View {
  @Binding var selectedSidebarTab: SidebarTab
  @Binding var selectedList: MailingList?
  var mailingLists: [MailingList]
  var isLoading: Bool = false
  @Binding var searchText: String
  var onSelectList: ((MailingList) -> Void)? = nil
  @FocusState private var isSearchFocused: Bool

  private var filteredLists: [MailingList] {
    if searchText.isEmpty {
      return mailingLists
    }
    return mailingLists.filter { list in
      list.name.localizedCaseInsensitiveContains(searchText)
        || list.desc.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Compact Xcode-style icon row
      HStack(spacing: 6) {
        ForEach(SidebarTab.allCases, id: \.self) { tab in
          SidebarTabButton(tab: tab, isSelected: selectedSidebarTab == tab) {
            withAnimation(Animation.userPreference) {
              selectedSidebarTab = tab
            }
          }
        }
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity)

      // Content area
      VStack(spacing: 0) {
        // Section header
        HStack {
          Text(selectedSidebarTab.label)
            .font(.headline)
            .foregroundColor(.primary)
            .background(Color(.windowBackgroundColor).opacity(0))
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // .background(Color(.windowBackgroundColor).opacity(0.3))

        // Content
        Group {
          switch selectedSidebarTab {
          case .lists:
            if isLoading {
              ProgressView("Loading lists...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnimationConstants.fadeInOut)
            } else {
              VStack(spacing: 0) {
                // Search bar with animation
                TextField("Search mailing lists", text: $searchText)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .padding([.horizontal, .top], 8)
                  .focused($isSearchFocused)
                  .scaleEffect(isSearchFocused ? AnimationConstants.selectedScale : 1.0)
                  .animation(Animation.userPreferenceQuick, value: isSearchFocused)

                // Filtered list
                List(selection: $selectedList) {
                  ForEach(filteredLists, id: \.id) { list in
                    MailingListItemView(
                      list: list,
                      isSelected: selectedList == list,
                      onSelect: {
                        withAnimation(Animation.userPreferenceQuick) {
                          selectedList = list
                        }
                        onSelectList?(list)
                      }
                    )
                  }
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
              .transition(AnimationConstants.slideFromTrailing)
            }
          case .favorites:
            Text("Favorites")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .transition(AnimationConstants.slideFromTrailing)
          case .tags:
            Text("Tags")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .transition(AnimationConstants.slideFromTrailing)
          case .settings:
            SettingsView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .transition(AnimationConstants.slideFromTrailing)
          }
        }
        .animation(Animation.userPreference, value: selectedSidebarTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
    .background(.ultraThinMaterial)
  }
}

struct MailingListItemView: View {
  let list: MailingList
  let isSelected: Bool
  let onSelect: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    HStack {
      Text(list.name)
        .font(.system(size: 12, weight: .regular))
        .lineLimit(1)
      Spacer()
      Text(list.desc)
        .font(.system(size: 10))
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
    .padding(.vertical, 1)
    .background(
      RoundedRectangle(cornerRadius: 3)
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.2)
            : (isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .scaleEffect(
          isSelected
            ? AnimationConstants.selectedScale : (isHovered ? AnimationConstants.hoverScale : 1.0))
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

#Preview {
  SidebarView(
    selectedSidebarTab: .constant(.lists), selectedList: .constant(nil),
    mailingLists: [MailingList(name: "linux-kernel", desc: "Linux Kernel Mailing List")],
    isLoading: false,
    searchText: .constant("")
  )
}
