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

class AppDelegate: NSObject, NSApplicationDelegate, NSDraggingDestination {
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
        statusItem.button?.image = NSImage(systemSymbolName: "square.and.arrow.up.fill", accessibilityDescription: "WordUp")

        // Set up button action for clicks
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        // Make the button accept drops and set dragging destination
        if let window = statusItem.button?.window {
            window.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
            window.contentView?.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
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
    }

    @objc private func closePopoverForAuthorization() {
        if popover.isShown {
            popover.performClose(nil)
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

                await MainActor.run {
                    showNotification(title: "Authentication Successful", body: "Connected to \(siteURL)")
                    // Close any open authentication windows
                    if let window = NSApp.windows.first(where: { $0.title.contains("Authentication") }) {
                        window.close()
                    }

                    // Show the menu briefly to display authenticated state
                    if !popover.isShown {
                        if let button = statusItem.button {
                            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                            // Auto-hide after 3 seconds to show the authenticated state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                if self.popover.isShown {
                                    self.popover.performClose(nil)
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
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }

    // MARK: - NSDraggingDestination

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            Task {
                for url in urls {
                    await self.uploadFile(url)
                }
            }
            return true
        }

        return false
    }

    private func uploadFile(_ fileURL: URL) async {
        guard self.wordPressService.isAuthenticated else {
            // Show notification that user needs to authenticate
            await MainActor.run {
                self.showNotification(title: "Not Authenticated", body: "Please authenticate first in the menu.")
            }
            return
        }

        do {
            let mediaURL = try await self.wordPressService.uploadFile(fileURL)
            await MainActor.run {
                self.copyToClipboard(mediaURL)
                self.showNotification(title: "Upload Successful", body: "Media URL copied to clipboard")
            }
        } catch {
            await MainActor.run {
                self.showNotification(title: "Upload Failed", body: error.localizedDescription)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
}

// Note: DragDropView has been removed - drag handling is now done directly in AppDelegate
