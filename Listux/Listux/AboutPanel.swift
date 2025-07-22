#if os(macOS)
  import AppKit

  class AboutPanel {
    static func show() {
      let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
      let version =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
      let copyright = "Copyright © 2025 wheatfox <wheatfox17@icloud.com>"
      let homepage = GITHUB_HOMEPAGE

      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
      )
      panel.title = "About \(appName)"
      panel.isFloatingPanel = true
      panel.level = .floating

      let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 240))

      if let icon = NSApp.applicationIconImage {
        let imageView = NSImageView(image: icon)
        imageView.frame = NSRect(x: 134, y: 140, width: 72, height: 72)
        #if swift(>=5.3)
          imageView.imageScaling = .scaleProportionallyUpOrDown
        #else
          imageView.imageScaling = .scaleAxesIndependently
        #endif
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 16
        imageView.layer?.masksToBounds = true
        contentView.addSubview(imageView)
      }

      let nameLabel = NSTextField(labelWithString: appName)
      nameLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
      nameLabel.alignment = .center
      nameLabel.frame = NSRect(x: 0, y: 120, width: 340, height: 24)

      let versionLabel = NSTextField(labelWithString: "Version \(version)")
      versionLabel.font = NSFont.systemFont(ofSize: 12)
      versionLabel.textColor = .secondaryLabelColor
      versionLabel.alignment = .center
      versionLabel.frame = NSRect(x: 0, y: 104, width: 340, height: 18)

      let descLabel = NSTextField(labelWithString: "Linux Kernel Mailing List Client")
      descLabel.font = NSFont.systemFont(ofSize: 13)
      descLabel.textColor = .secondaryLabelColor
      descLabel.alignment = .center
      descLabel.frame = NSRect(x: 0, y: 84, width: 340, height: 18)

      let copyrightLabel = NSTextField(labelWithString: copyright)
      copyrightLabel.font = NSFont.systemFont(ofSize: 11)
      copyrightLabel.textColor = .secondaryLabelColor
      copyrightLabel.alignment = .center
      copyrightLabel.frame = NSRect(x: 0, y: 60, width: 340, height: 16)

      let homepageLabel = NSTextField(labelWithString: homepage)
      homepageLabel.font = NSFont.systemFont(ofSize: 11)
      homepageLabel.textColor = .linkColor
      homepageLabel.alignment = .center
      homepageLabel.frame = NSRect(x: 0, y: 44, width: 340, height: 16)
      homepageLabel.isSelectable = true

      contentView.addSubview(nameLabel)
      contentView.addSubview(versionLabel)
      contentView.addSubview(descLabel)
      contentView.addSubview(copyrightLabel)
      contentView.addSubview(homepageLabel)

      panel.contentView = contentView
      panel.center()
      panel.makeKeyAndOrderFront(nil)
    }
  }
#endif
