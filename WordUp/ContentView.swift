//
//  ContentView.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var wordPressService: WordPressService
    @State private var showingAuthWindow = false
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if wordPressService.isAuthenticated {
                Text("Authenticated")
                    .foregroundColor(.green)
                    .font(.headline)

                Divider()

                Button("Upload Files...") {
                    openFilePicker()
                }

                Button("Settings") {
                    showingSettings = true
                }
            } else {
                Text("Not Authenticated")
                    .foregroundColor(.red)
                    .font(.headline)

                Divider()

                Button("Authenticate") {
                    showingAuthWindow = true
                }
            }

            Divider()

            Button("Quit WordUp") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 200)
        .padding()
        .sheet(isPresented: $showingAuthWindow) {
            AuthenticationView()
                .environmentObject(wordPressService)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(wordPressService)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task {
                await handleFileDrop(providers: providers)
            }
            return true
        }
    }


    private func openFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [
            .png, .jpeg, .gif, .webP,
            UTType(filenameExtension: "jpg")!,
            UTType(filenameExtension: "svg")!,
            UTType(filenameExtension: "webp")!
        ]
        openPanel.title = "Select Files to Upload"

        // Run the panel modally to ensure it works properly
        let response = openPanel.runModal()
        if response == .OK {
            Task {
                await uploadFiles(Array(openPanel.urls))
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) async {
        for provider in providers {
            do {
                let urlData = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil),
                   isValidUploadFile(url) {
                    await uploadFile(url)
                }
            } catch {
                print("Error loading dropped item: \(error)")
            }
        }
    }

    private func uploadFile(_ url: URL) async {
        do {
            let mediaURL = try await wordPressService.uploadFile(url)
            print("File uploaded successfully: \(mediaURL)")

            // Copy the media URL to clipboard
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(mediaURL, forType: .string)
            }

            // Show success notification
            await showNotification(title: "Upload Successful", body: "Media URL copied to clipboard")

        } catch {
            print("Failed to upload \(url.lastPathComponent): \(error.localizedDescription)")

            // Show error notification
            await showNotification(title: "Upload Failed", body: "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func uploadFiles(_ urls: [URL]) async {
        for url in urls {
            await uploadFile(url)
        }
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

    private func isValidUploadFile(_ url: URL) -> Bool {
        let supportedExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg"]
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension) && url.isFileURL
    }
}

#Preview {
    ContentView()
}
