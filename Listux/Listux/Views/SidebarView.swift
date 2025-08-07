import SwiftData
import SwiftUI

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
    HStack(spacing: 8) {
      Image(systemName: tab.systemImage)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(isSelected ? .accentColor : .secondary)
      Text(tab.label)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(isSelected ? .primary : .secondary)
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    )
    .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
    .contentShape(Rectangle())
    .onTapGesture(perform: action)
    .onHover { hovering in
      isHovered = hovering
    }
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
  @State private var favoriteMessageService = FavoriteMessageService.shared

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      try? modelContext.save()
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
    var tags = favoriteMessageService.getAllTags()
    if !favoriteMessageService.getUntaggedMessages().isEmpty {
      tags.insert("Untagged", at: 0)
    }
    return tags
  }

  var body: some View {
    VStack(spacing: 0) {
      // Navigation tabs
      VStack(spacing: 4) {
        ForEach(SidebarTab.allCases, id: \.self) { tab in
          SidebarTabButton(tab: tab, isSelected: selectedSidebarTab == tab) {
            selectedSidebarTab = tab
            if tab == .favorites {
              selectedTag = nil
              onSelectTag?(nil)
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
        Group {
          switch selectedSidebarTab {
          case .lists:
            listsContent
          case .favorites:
            favoritesContent
          case .settings:
            SettingsView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .transition(AnimationConstants.slideFromTrailing)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 240, idealWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    #if os(macOS)
      .background(Color(NSColor.controlBackgroundColor))
    #else
      .background(.ultraThinMaterial)
    #endif
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }

  @ViewBuilder
  private var listsContent: some View {
    if isLoading {
      ProgressView("Loading lists...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(AnimationConstants.fadeInOut)
    } else {
      VStack(spacing: 0) {
        // Search bar
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
            .fill(searchBarBackgroundColor)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  isSearchFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
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
                selectedList = list
                onSelectList?(list)
              },
              onPinToggle: {
                preference.togglePinned(list)
              }
            )
          }
        }
        .listStyle(listStyle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .transition(AnimationConstants.slideFromTrailing)
    }
  }

  @ViewBuilder
  private var favoritesContent: some View {
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
            HStack(spacing: 8) {
              Image(systemName: tag == "Untagged" ? "tag.slash" : "tag")
                .font(.system(size: 12))
                .foregroundColor(tag == "Untagged" ? .secondary : .blue)

              VStack(alignment: .leading, spacing: 2) {
                Text(tag)
                  .font(.system(size: 13, weight: .medium))
                  .lineLimit(1)
                Text(
                  "\(getMessageCount(for: tag)) message\(getMessageCount(for: tag) == 1 ? "" : "s")"
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
              }

              Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .onTapGesture {
              selectedTag = tag
              onSelectTag?(tag)
            }
          }
        }
        .listStyle(listStyle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .transition(AnimationConstants.slideFromTrailing)
  }

  private var searchBarBackgroundColor: Color {
    #if os(macOS)
      Color(.controlBackgroundColor)
    #else
      Color(.systemGray6)
    #endif
  }

  private func getMessageCount(for tag: String) -> Int {
    if tag == "Untagged" {
      return favoriteMessageService.getUntaggedMessages().count
    } else {
      return favoriteMessageService.getMessagesWithTag(tag).count
    }
  }

  private var listStyle: some ListStyle {
    #if os(macOS)
      .sidebar
    #else
      .insetGrouped
    #endif
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
