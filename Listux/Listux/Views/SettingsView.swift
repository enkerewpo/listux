import SwiftUI
import SwiftData

struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var preferences = UserPreferences.shared
  @State private var showingResetAlert = false
  @State private var showingClearDataAlert = false
  @State private var tempBaseURL: String = ""

  var body: some View {
    ScrollView {
      VStack(spacing: 15) {

        // Network Settings
        SettingsCard(title: "Network", icon: "network") {
          VStack(alignment: .leading, spacing: 11) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text("Base URL")
                  .font(.headline)
                  .fontWeight(.medium)
                Text("Mailing list archive server")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Button("Reset") {
                tempBaseURL = "https://lore.kernel.org"
                preferences.baseURL = tempBaseURL
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }

            TextField("https://lore.kernel.org", text: $tempBaseURL)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .onChange(of: tempBaseURL) { _, newValue in
                preferences.baseURL = newValue
              }
          }
        }

        // Animation Settings
        SettingsCard(title: "Animations", icon: "sparkles") {
          VStack(alignment: .leading, spacing: 11) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Enable Animations")
                  .font(.headline)
                  .fontWeight(.medium)
                Text("Smooth transitions and effects")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Toggle("", isOn: $preferences.animationsEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }

            if preferences.animationsEnabled {
              VStack(alignment: .leading, spacing: 8) {
                Text("Animation Speed")
                  .font(.subheadline)
                  .fontWeight(.medium)

                HStack(spacing: 12) {
                  ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                    SpeedButton(
                      speed: speed,
                      isSelected: preferences.animationSpeed == speed
                    ) {
                      preferences.animationSpeed = speed
                    }
                  }
                }
              }
              .padding(.leading, 4)
            }
          }
        }

        // Interface Settings
        SettingsCard(title: "Interface", icon: "slider.horizontal.3") {
          VStack(alignment: .leading, spacing: 11) {
            // Auto Refresh
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Auto Refresh")
                    .font(.headline)
                    .fontWeight(.medium)
                  Text("Automatically update content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $preferences.autoRefreshEnabled)
                  .toggleStyle(SwitchToggleStyle(tint: .accentColor))
              }

              if preferences.autoRefreshEnabled {
                HStack {
                  Text("Interval")
                    .font(.subheadline)
                    .fontWeight(.medium)
                  Spacer()
                  Picker("", selection: $preferences.autoRefreshInterval) {
                    Text("1 min").tag(60)
                    Text("5 min").tag(300)
                    Text("10 min").tag(600)
                    Text("30 min").tag(1800)
                  }
                  .pickerStyle(MenuPickerStyle())
                  .frame(width: 80)
                }
                .padding(.leading, 4)
              }
            }
          }
        }

        // Data Management
        SettingsCard(title: "Data Management", icon: "trash") {
          VStack(alignment: .leading, spacing: 11) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Clear Local Data")
                  .font(.headline)
                  .fontWeight(.medium)
                Text("Remove all favorites, tags, and local preferences")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Button("Clear") {
                showingClearDataAlert = true
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              .foregroundColor(.red)
            }
          }
        }

        // Reset Button
        Button(action: {
          showingResetAlert = true
        }) {
          HStack {
            Image(systemName: "arrow.clockwise")
            Text("Reset All Settings")
          }
          .foregroundColor(.red)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.red.opacity(0.3), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 20)
    }
    .onAppear {
      tempBaseURL = preferences.baseURL
    }
    .alert("Reset Settings", isPresented: $showingResetAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        resetToDefaults()
      }
    } message: {
      Text("This will reset all settings to their default values. This action cannot be undone.")
    }
    .alert("Clear Local Data", isPresented: $showingClearDataAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Clear Local Data", role: .destructive) {
        SettingsManager.shared.clearAllData(modelContext: modelContext)
      }
    } message: {
      Text("This will permanently delete all favorites, tags, and local preferences. Mailing lists and messages will remain intact. This action cannot be undone.")
    }
  }

  private func resetToDefaults() {
    preferences.baseURL = "https://lore.kernel.org"
    preferences.animationsEnabled = true
    preferences.animationSpeed = .standard
    preferences.autoRefreshEnabled = false
    preferences.autoRefreshInterval = 300
    tempBaseURL = preferences.baseURL
  }
}

struct SettingsCard<Content: View>: View {
  let title: String
  let icon: String
  let content: Content

  init(title: String, icon: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.icon = icon
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: icon)
          .font(.title3)
          .foregroundColor(.accentColor)
          .frame(width: 24)
        Text(title)
          .font(.headline)
          .fontWeight(.semibold)
      }

      content
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        #if os(macOS)
          .fill(Color(.windowBackgroundColor))
        #else
          .fill(Color(.systemBackground))
        #endif
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    )
  }
}

struct SpeedButton: View {
  let speed: AnimationSpeed
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(speed.displayName)
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            #if os(macOS)
              .fill(isSelected ? Color.accentColor : Color(.windowBackgroundColor))
            #else
              .fill(isSelected ? Color.accentColor : Color(.systemBackground))
            #endif
        )
        .foregroundColor(isSelected ? .white : .primary)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  SettingsView()
}
