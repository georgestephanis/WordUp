//
//  AppDelegate.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate, NSDraggingDestination {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let wordPressService = WordPressService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
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
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// Note: DragDropView has been removed - drag handling is now done directly in AppDelegate
