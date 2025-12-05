//
//  AppDelegate.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let wordPressService = WordPressService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "WordUp")

        // Make the status item accept drops
        statusItem.button?.window?.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

        // Set up the drag delegate
        let dragView = DragDropView(wordPressService: self.wordPressService)
        statusItem.button?.window?.contentView = NSHostingView(rootView: dragView)
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
}

struct DragDropView: View {
    @StateObject var wordPressService: WordPressService
    @State private var isDragOver = false

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 22, height: 22)
                .onTapGesture {
                    NSApp.sendAction(#selector(AppDelegate.togglePopover(_:)), to: nil, from: nil)
                }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            Task {
                await handleDrop(providers: providers)
            }
            return true
        }
        .overlay {
            if isDragOver {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 30, height: 30)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) async {
        for provider in providers {
            do {
                let urlData = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    await uploadFile(url)
                }
            } catch {
                print("Error loading dropped item: \(error)")
            }
        }
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
