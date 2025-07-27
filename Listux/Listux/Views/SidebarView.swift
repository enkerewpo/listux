import SwiftUI
import SwiftData

enum SidebarTab: Hashable, CaseIterable {
  case lists, favorites, settings
  var systemImage: String {
    switch self {
    case .lists: return "tray.full"
    case .favorites: return "star"
    case .settings: return "gear"
    }
  }
  var label: String {
    switch self {
    case .lists: return "Lists"
    case .favorites: return "Favorites"
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
  @Binding var selectedTag: String?
  var mailingLists: [MailingList]
  var isLoading: Bool = false
  @Binding var searchText: String
  var onSelectList: ((MailingList) -> Void)? = nil
  var onSelectTag: ((String?) -> Void)? = nil
  @FocusState private var isSearchFocused: Bool
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

  private var filteredLists: [MailingList] {
    if searchText.isEmpty {
      return mailingLists
    }
    return mailingLists.filter { list in
      list.name.localizedCaseInsensitiveContains(searchText)
        || list.desc.localizedCaseInsensitiveContains(searchText)
    }
  }
  
  private var sortedLists: [MailingList] {
    let pinned = filteredLists.filter { $0.isPinned }
    let unpinned = filteredLists.filter { !$0.isPinned }
    return pinned + unpinned
  }
  
  private var allTags: [String] {
    var tags = preference.getAllTags()
    // Add "Untagged" option if there are untagged messages
    if !preference.getUntaggedMessages().isEmpty {
      tags.insert("Untagged", at: 0)
    }
    return tags
  }

  var body: some View {
    VStack(spacing: 0) {
      // Compact Xcode-style icon row
      HStack(spacing: 6) {
        ForEach(SidebarTab.allCases, id: \.self) { tab in
          SidebarTabButton(tab: tab, isSelected: selectedSidebarTab == tab) {
            withAnimation(Animation.userPreference) {
              selectedSidebarTab = tab
              if tab == .favorites {
                selectedTag = nil
                onSelectTag?(nil)
              }
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
            #if os(macOS)
              .background(Color(.windowBackgroundColor).opacity(0))
            #else
              .background(Color(.systemBackground).opacity(0))
            #endif
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

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
                  ForEach(sortedLists, id: \.id) { list in
                    MailingListItemView(
                      list: list,
                      isSelected: selectedList == list,
                      isPinned: list.isPinned,
                      onSelect: {
                        withAnimation(Animation.userPreferenceQuick) {
                          selectedList = list
                        }
                        onSelectList?(list)
                      },
                      onPinToggle: {
                        withAnimation(Animation.userPreferenceQuick) {
                          preference.togglePinned(list)
                        }
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
            VStack(spacing: 0) {
              if allTags.isEmpty {
                Text("No favorite messages")
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .transition(AnimationConstants.fadeInOut)
              } else {
                List(selection: $selectedTag) {
                  ForEach(allTags, id: \.self) { tag in
                    TagItemView(
                      tag: tag,
                      isSelected: selectedTag == tag,
                      messageCount: tag == "Untagged" ? 
                        preference.getUntaggedMessages().count : 
                        preference.getMessagesWithTag(tag).count,
                      onSelect: {
                        withAnimation(Animation.userPreferenceQuick) {
                          selectedTag = tag
                          onSelectTag?(tag)
                        }
                      }
                    )
                  }
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
            }
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
  let isPinned: Bool
  let onSelect: () -> Void
  let onPinToggle: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    HStack {
      // Pin indicator
      if isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 8))
          .foregroundColor(.orange)
      }
      
      VStack(alignment: .leading, spacing: 2) {
        Text(list.name)
          .font(.system(size: 12, weight: .regular))
          .lineLimit(1)
        Text(list.desc)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      
      Spacer()
      
      // Pin toggle button
      Button(action: onPinToggle) {
        Image(systemName: isPinned ? "pin.fill" : "pin")
          .font(.system(size: 10))
          .foregroundColor(isPinned ? .orange : .secondary)
          .scaleEffect(isPinned ? AnimationConstants.favoriteScale : 1.0)
      }
      .buttonStyle(.plain)
      .animation(AnimationConstants.springQuick, value: isPinned)
    }
    .padding(.vertical, 4)
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

struct TagItemView: View {
  let tag: String
  let isSelected: Bool
  let messageCount: Int
  let onSelect: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    HStack {
      Image(systemName: tag == "Untagged" ? "tag.slash" : "tag")
        .font(.system(size: 10))
        .foregroundColor(tag == "Untagged" ? .secondary : .blue)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(tag)
          .font(.system(size: 12, weight: .regular))
          .lineLimit(1)
        Text("\(messageCount) message\(messageCount == 1 ? "" : "s")")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      
      Spacer()
    }
    .padding(.vertical, 4)
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
    selectedSidebarTab: .constant(.lists), 
    selectedList: .constant(nil),
    selectedTag: .constant(nil),
    mailingLists: [MailingList(name: "linux-kernel", desc: "Linux Kernel Mailing List")],
    isLoading: false,
    searchText: .constant(""),
    onSelectList: nil,
    onSelectTag: nil
  )
}
