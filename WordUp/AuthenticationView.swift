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
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var showSuccess: Bool = false
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

                VStack(alignment: .leading) {
                    Text("Username")
                        .font(.headline)
                    TextField("admin", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAuthenticating)
                }

                VStack(alignment: .leading) {
                    Text("Application Password")
                        .font(.headline)
                    SecureField("Application password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAuthenticating)
                }
            }
            .padding(.horizontal)

            if let errorMessage = wordPressService.errorMessage {
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

                Button("Authenticate") {
                    authenticate()
                }
                .disabled(baseURL.isEmpty || username.isEmpty || password.isEmpty || isAuthenticating)
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

    private func authenticate() {
        isAuthenticating = true

        Task {
            do {
                try await wordPressService.authenticate(
                    baseURL: baseURL,
                    username: username,
                    password: password
                )
            } catch {
                DispatchQueue.main.async {
                    self.wordPressService.errorMessage = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
