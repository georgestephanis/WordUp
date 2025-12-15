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
    @State private var isVerifyingAuth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if wordPressService.isAuthenticated {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authenticated")
                        .foregroundColor(.green)
                        .font(.headline)

                    if let url = wordPressService.authenticatedURL {
                        Text("Site: \(url)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let username = wordPressService.authenticatedUsername {
                        Text("User: \(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Button("Upload Files...") {
                    openFilePicker()
                }

                Button(isVerifyingAuth ? "Verifying..." : "Verify Authentication") {
                    Task {
                        await verifyAuthentication()
                    }
                }
                .disabled(isVerifyingAuth)

                Button("Settings") {
                    // Settings window will be implemented
                }

                Divider()

                Button("Sign Out") {
                    wordPressService.signOut()
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
    }

    private func verifyAuthentication() async {
        guard wordPressService.isAuthenticated else { return }

        isVerifyingAuth = true
        defer { isVerifyingAuth = false }

        do {
            try await wordPressService.verifyAuthentication()
            // Success - authentication is still valid
            print("Authentication verified successfully")
        } catch {
            print("Authentication verification failed: \(error.localizedDescription)")
            // If verification fails, sign out the user
            wordPressService.signOut()
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

    private func uploadFiles(_ urls: [URL]) async {
        for url in urls {
            do {
                let mediaURL = try await wordPressService.uploadFile(url)
                print("File uploaded successfully: \(mediaURL)")

                // Copy the media URL to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(mediaURL, forType: .string)

                // Show success notification
                do {
                    let content = UNMutableNotificationContent()
                    content.title = "Upload Successful"
                    content.body = "Media URL copied to clipboard"
                    content.sound = .default

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    print("Error showing notification: \(error.localizedDescription)")
                }

            } catch {
                print("Failed to upload \(url.lastPathComponent): \(error.localizedDescription)")

                // Show error notification
                do {
                    let content = UNMutableNotificationContent()
                    content.title = "Upload Failed"
                    content.body = "\(url.lastPathComponent): \(error.localizedDescription)"
                    content.sound = .default

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    print("Error showing notification: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
