import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences.shared
    @State private var showingResetAlert = false
    @State private var tempBaseURL: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Text("Customize your Listux experience")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Network Settings
                SettingsCard(title: "Network", icon: "network") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
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
                    VStack(alignment: .leading, spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 16) {                        
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
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
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
                .fill(Color(.windowBackgroundColor))
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
                        .fill(isSelected ? Color.accentColor : Color(.windowBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
