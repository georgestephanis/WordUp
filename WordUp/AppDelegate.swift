//
//  AppDelegate.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let wordPressService = WordPressService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        requestNotificationAuthorization()
        setupURLSchemeHandling()
        setupNotifications()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = createCustomIcon()

        // Set up button action for clicks
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        // Add drag view for direct drag-and-drop on the icon
        if let button = statusItem.button {
            let dragView = DraggableStatusView(frame: button.bounds, appDelegate: self)
            dragView.autoresizingMask = [.width, .height]
            button.addSubview(dragView)
        }
    }

    private func createCustomIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // Create a circle outline with "W"
        let circleRect = NSRect(x: 0, y: 0, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)

        // Set circle outline color (WordPress blue-ish)
        NSColor.systemBlue.setStroke()
        circlePath.lineWidth = 1.5
        circlePath.stroke()

        // Draw "W" text
        let wRect = NSRect(x: 2, y: 1, width: 10, height: 12)
        let wString = NSAttributedString(string: "W", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor.systemBlue
        ])
        wString.draw(in: wRect)

        // Draw upward arrow further to the right (moved from x:15 to x:16)
        let arrowPath = NSBezierPath()
        // Arrow shaft - moved right and made bolder
        arrowPath.move(to: NSPoint(x: 16, y: 4))
        arrowPath.line(to: NSPoint(x: 16, y: 12))
        // Arrow head - adjusted for new position
        arrowPath.line(to: NSPoint(x: 14, y: 10))
        arrowPath.move(to: NSPoint(x: 16, y: 12))
        arrowPath.line(to: NSPoint(x: 18, y: 10))

        // Green color to indicate website connection
        NSColor.systemGreen.setStroke()
        arrowPath.lineWidth = 2.0 // Made bolder
        arrowPath.stroke()

        image.unlockFocus()

        image.isTemplate = true // Makes it adapt to menu bar appearance
        return image
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 300)
        popover.behavior = .semitransient  // More responsive dismissal when clicking outside
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(wordPressService))
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
            // Note: Even if not granted, local notifications might still work on some systems
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopoverForAuthorization),
            name: NSNotification.Name("WordUpAuthorizationStarted"),
            object: nil
        )

        // Note: Automatic screenshot detection is not available via public APIs
        // Users must manually upload screenshots using drag & drop or the Upload Files button
    }

    @objc private func closePopoverForAuthorization() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

// Screenshot detection methods removed - not available via public APIs

    // MARK: - URL Scheme Handling

    private func setupURLSchemeHandling() {
        // Register for URL scheme events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        print("Received URL: \(url.absoluteString)")

        // Handle wordup:// scheme URLs from WordPress authorization
        if url.scheme == "wordup" {
            handleAuthorizationCallback(url: url)
        }
    }

    private func handleAuthorizationCallback(url: URL) {
        // Parse the callback URL parameters
        // Expected format: wordup://auth?site_url=https://example.com&user_login=username&password=app_password
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let queryItems = components?.queryItems else {
            showAuthError("Invalid authorization response")
            return
        }

        var siteURL: String?
        var userLogin: String?
        var password: String?

        for item in queryItems {
            switch item.name {
            case "site_url":
                siteURL = item.value
            case "user_login":
                userLogin = item.value
            case "password":
                password = item.value
            default:
                break
            }
        }

        guard let siteURL = siteURL, let userLogin = userLogin, let password = password else {
            showAuthError("Missing required authorization parameters")
            return
        }

        // Authenticate with the provided credentials
        Task {
            do {
                try await wordPressService.authenticate(
                    baseURL: siteURL,
                    username: userLogin,
                    password: password
                )

                await showNotification(title: "Authentication Successful", body: "Connected to \(siteURL)")

                await MainActor.run {
                    // Close any open authentication windows
                    if let window = NSApp.windows.first(where: { $0.title.contains("Authentication") }) {
                        window.close()
                    }

                    // Show the menu briefly to display authenticated state
                    if !popover.isShown {
                        if let button = statusItem.button {
                            DispatchQueue.main.async {
                                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                                // Auto-hide after 3 seconds to show the authenticated state
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    if self.popover.isShown {
                                        self.popover.performClose(nil)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    showAuthError("Authentication failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showAuthError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Authentication Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                // Ensure no window focus issues when showing popover
                DispatchQueue.main.async {
                    self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                }
            }
        }
    }

    // Drag-and-drop is handled via ContentView.onDrop when the popover is open

    public func uploadFile(_ fileURL: URL) async {
        guard self.wordPressService.isAuthenticated else {
            // Show notification that user needs to authenticate
            await self.showNotification(title: "Not Authenticated", body: "Please authenticate first in the menu.")
            return
        }

        do {
            let mediaURL = try await self.wordPressService.uploadFile(fileURL)
            await MainActor.run {
                self.copyToClipboard(mediaURL)
            }
            await self.showNotification(title: "Upload Successful", body: "Media URL copied to clipboard")
        } catch {
            await self.showNotification(title: "Upload Failed", body: error.localizedDescription)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showNotification(title: String, body: String) async {
        do {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error showing notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Draggable Status View

class DraggableStatusView: NSView {
    weak var appDelegate: AppDelegate?

    init(frame frameRect: NSRect, appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(frame: frameRect)
        setup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Register for file URL drag types
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

        // Make sure we don't interfere with button clicks
        // The superview (status item button) will handle clicks
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            // Check if any of the URLs are valid upload files
            let validFiles = urls.filter { isValidUploadFile($0) }
            return validFiles.isEmpty ? [] : .copy
        }
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let validFiles = urls.filter { isValidUploadFile($0) }
            return validFiles.isEmpty ? [] : .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let validUrls = urls.filter { isValidUploadFile($0) }
            if !validUrls.isEmpty {
                Task {
                    for url in validUrls {
                        if let appDelegate = appDelegate {
                            await appDelegate.uploadFile(url)
                        }
                    }
                }
                return true
            }
        }

        return false
    }

    private func isValidUploadFile(_ url: URL) -> Bool {
        let supportedExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg"]
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension) && url.isFileURL
    }
}

// Note: DragDropView has been removed - drag handling is now done directly in AppDelegate
