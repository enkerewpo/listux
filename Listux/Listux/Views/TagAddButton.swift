import SwiftUI

struct TagAddButton: View {
  let messageId: String
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    Button(action: {
      showingTagInput = true
    }) {
      Image(systemName: "plus.circle")
        .font(.system(size: 10))
        .foregroundColor(.blue)
    }
    .buttonStyle(.plain)
    #if os(macOS)
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
              addTag()
            }
            .disabled(newTag.isEmpty)
          }
        }
        .padding()
        .frame(width: 200)
      }
    #else
      .alert("Add Tag", isPresented: $showingTagInput) {
        TextField("Tag name", text: $newTag)
        Button("Cancel", role: .cancel) {
          showingTagInput = false
          newTag = ""
        }
        Button("Add") {
          addTag()
        }
      } message: {
        Text("Enter a tag name for this message")
      }
    #endif
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
  
  private func addTag() {
    if !newTag.isEmpty {
      favoriteMessageService.addTag(newTag, to: messageId)
      newTag = ""
    }
    showingTagInput = false
  }
}
