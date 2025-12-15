//
//  ContentView.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var wordPressService = WordPressService()
    @State private var showingAuthWindow = false

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
                    // File upload logic will be implemented
                }

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
}

#Preview {
    ContentView()
}
