import SwiftUI

enum SidebarTab: Hashable, CaseIterable {
  case lists, favorites, tags
  var systemImage: String {
    switch self {
    case .lists: return "tray.full"
    case .favorites: return "star"
    case .tags: return "tag"
    }
  }
  var label: String {
    switch self {
    case .lists: return "Lists"
    case .favorites: return "Favorites"
    case .tags: return "Tags"
    }
  }
}

private struct SidebarTabButton: View {
  let tab: SidebarTab
  let isSelected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: tab.systemImage)
        .font(.system(size: 16, weight: .regular))
        .foregroundColor(isSelected ? .accentColor : .secondary)
        .padding(4)
        .frame(width: 28, height: 28)
        .background(
          isSelected
            ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.18)))
            : AnyView(Color.clear)
        )
        .help(tab.label)
    }
    .buttonStyle(.plain)
  }
}

struct SidebarView: View {
  @Binding var selectedSidebarTab: SidebarTab
  @Binding var selectedList: MailingList?
  var mailingLists: [MailingList]
  var isLoading: Bool = false
  @Binding var searchText: String
  var onSelectList: ((MailingList) -> Void)? = nil
  var body: some View {
    VStack(spacing: 0) {
      // Compact Xcode-style icon row
      HStack(spacing: 6) {
        ForEach(SidebarTab.allCases, id: \.self) { tab in
          SidebarTabButton(tab: tab, isSelected: selectedSidebarTab == tab) {
            selectedSidebarTab = tab
          }
        }
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity)
      // Divider()
      // Content area
      Group {
        switch selectedSidebarTab {
        case .lists:
          if isLoading {
            ProgressView("Loading lists...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            VStack(spacing: 0) {
              // Search bar
              TextField("Search mailing lists", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.horizontal, .top], 8)
              // Filtered list
              List(selection: $selectedList) {
                ForEach(
                  mailingLists.filter {
                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                      || $0.desc.localizedCaseInsensitiveContains(searchText)
                  }, id: \.id
                ) { list in
                  HStack {
                    VStack(alignment: .leading, spacing: 0) {
                      Text(list.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                      Text(list.desc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                  }
                  .padding(.vertical, 2)
                  .background(selectedList == list ? Color.accentColor.opacity(0.2) : Color.clear)
                  .cornerRadius(6)
                  .onTapGesture {
                    selectedList = list
                    onSelectList?(list)
                  }
                }
              }
              .listStyle(.sidebar)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
        case .favorites:
          Text("Favorites")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .tags:
          Text("Tags")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .animation(.default, value: selectedSidebarTab)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 180, maxWidth: .infinity, maxHeight: .infinity)
    .background(.ultraThinMaterial)
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
