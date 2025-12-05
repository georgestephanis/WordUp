//
//  AuthenticationView.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var wordPressService = WordPressService()
    @State private var baseURL: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("WordPress Authentication")
                .font(.title)
                .padding(.top)

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading) {
                    Text("WordPress Site URL")
                        .font(.headline)
                    TextField("https://yoursite.com", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAuthenticating)
                }
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage ?? wordPressService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isAuthenticating)

                Button("Connect to WordPress") {
                    startAuthentication()
                }
                .disabled(baseURL.isEmpty || isAuthenticating)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 350)
        .padding()
        .onChange(of: wordPressService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .overlay {
            if showSuccess {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("Authenticated Successfully!")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func startAuthentication() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                let authURL = try await wordPressService.startAuthentication(baseURL: baseURL)

                // Open the authorization URL in the default browser
                await MainActor.run {
                    NSWorkspace.shared.open(authURL)
                    self.isAuthenticating = false
                }

                // Show instructions to the user
                await MainActor.run {
                    self.errorMessage = "Authorization page opened in your browser. Please approve the connection in WordPress, and you'll be redirected back to complete the setup."
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
