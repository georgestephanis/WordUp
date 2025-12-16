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

class AppDelegate: NSObject, NSApplicationDelegate, NSMetadataQueryDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var screenshotQuery: NSMetadataQuery?
    private var processedScreenshots = Set<URL>()
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

        setupScreenshotMonitoring()
    }

    @objc private func closePopoverForAuthorization() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

// MARK: - Screenshot Monitoring

    private func setupScreenshotMonitoring() {
        // Monitor for screenshot files using Spotlight metadata
        screenshotQuery = NSMetadataQuery()
        screenshotQuery?.delegate = self
        screenshotQuery?.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")

        // Set search scopes to Desktop and Desktop/Screenshots for better targeting
        let fileManager = FileManager.default
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        var searchScopes: [URL] = []

        if let desktopURL = desktopURL {
            searchScopes.append(desktopURL)
            let screenshotsURL = desktopURL.appendingPathComponent("Screenshots")
            searchScopes.append(screenshotsURL)
        }

        screenshotQuery?.searchScopes = searchScopes

        // Configure for live updates and notifications
        screenshotQuery?.notificationBatchingInterval = 0.1
        screenshotQuery?.operationQueue = .main

        // Start monitoring
        screenshotQuery?.start()

        // Also set up notification observer for additional reliability
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering(_:)),
            name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: screenshotQuery
        )

        print("Started monitoring for screenshots using Spotlight metadata")
        print("Monitoring paths: \(searchScopes.map { $0.path })")
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        print("Metadata query finished initial gathering. Found \(screenshotQuery?.resultCount ?? 0) existing screenshots")

        // Process any existing screenshots that match our criteria
        if let results = screenshotQuery?.results as? [NSMetadataItem] {
            for item in results {
                if let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    handleNewScreenshot(at: fileURL)
                }
            }
        }
    }

    // MARK: - NSMetadataQueryDelegate

    func metadataQuery(_ query: NSMetadataQuery, didUpdate results: [NSMetadataItem], resultChange: [Any]) {
        print("Metadata query updated with \(results.count) results")

        // Check all current results for new screenshots
        for item in results {
            if let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                handleNewScreenshot(at: fileURL)
            }
        }
    }

    private func handleNewScreenshot(at url: URL) {
        // Skip if we've already processed this screenshot
        guard !processedScreenshots.contains(url) else {
            return
        }

        print("Detected potential screenshot: \(url.path)")

        // Only upload screenshots if user is authenticated
        guard wordPressService.isAuthenticated else {
            print("Screenshot detected but user not authenticated - skipping upload")
            return
        }

        // Check if this is a recent screenshot (created within last 30 seconds to account for Spotlight indexing delay)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let timeSinceCreation = Date().timeIntervalSince(creationDate)
                print("Screenshot created \(timeSinceCreation) seconds ago")

                if timeSinceCreation > 30.0 {
                    // Skip old screenshots
                    print("Skipping old screenshot")
                    return
                }
            }
        } catch {
            print("Could not check screenshot creation date: \(error)")
            return
        }

        // Double-check that this is actually a screenshot by checking the filename
        let filename = url.lastPathComponent.lowercased()
        guard filename.hasPrefix("screenshot") || filename.hasPrefix("screen shot") else {
            print("Filename doesn't match screenshot pattern: \(filename)")
            return
        }

        // Mark as processed and upload
        processedScreenshots.insert(url)
        print("Auto-uploading screenshot: \(url.path)")

        Task {
            await uploadFile(url)
        }
    }

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
