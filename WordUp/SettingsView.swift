//
//  SettingsView.swift
//  WordUp
//
//  Created by George Stephanis on 12/15/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var wordPressService: WordPressService
    @State private var isVerifyingAuth = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title)
                .padding(.bottom, 8)

            // Connection Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Connection Details")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    if let url = wordPressService.authenticatedURL {
                        HStack {
                            Text("Site:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(url)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        }
                    }

                    if let username = wordPressService.authenticatedUsername {
                        HStack {
                            Text("User:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(username)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        }
                    }

                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(wordPressService.isAuthenticated ? "Connected" : "Disconnected")
                            .font(.subheadline)
                            .foregroundColor(wordPressService.isAuthenticated ? .green : .red)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.headline)

                VStack(spacing: 8) {
                    Button(isVerifyingAuth ? "Verifying Connection..." : "Verify Connection") {
                        Task {
                            await verifyAuthentication()
                        }
                    }
                    .disabled(isVerifyingAuth)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    Button("Sign Out") {
                        wordPressService.signOut()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .frame(width: 400, height: 350)
        .padding()
    }

    private func verifyAuthentication() async {
        guard wordPressService.isAuthenticated else { return }

        isVerifyingAuth = true
        defer { isVerifyingAuth = false }

        do {
            try await wordPressService.verifyAuthentication()
            // Success - show brief confirmation
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } catch {
            // Error will be shown via notification from WordPressService
            print("Authentication verification failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WordPressService())
}
