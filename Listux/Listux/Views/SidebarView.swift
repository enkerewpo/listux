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
      HStack(spacing: 8) {
        Image(systemName: tab.systemImage)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(isSelected ? .accentColor : .secondary)
        Text(tab.label)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(isSelected ? .primary : .secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
          )
      )
      .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isHovered)
    .animation(Animation.userPreferenceQuick, value: isSelected)
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
      // Navigation tabs with improved design
      VStack(spacing: 4) {
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
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()
        .padding(.horizontal, 12)

      // Content area
      VStack(spacing: 0) {
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
                // Search bar with improved spacing
                HStack {
                  Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                  TextField("Search mailing lists", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

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
                VStack(spacing: 8) {
                  Image(systemName: "star")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                  Text("No favorite messages")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
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
    .frame(minWidth: 240, idealWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    #if os(macOS)
    .background(Color(NSColor.controlBackgroundColor))
    #else
    .background(.ultraThinMaterial)
    #endif
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
