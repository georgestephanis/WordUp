//
//  WordPressService.swift
//  WordUp
//
//  Created by George Stephanis on 12/5/25.
//

import Foundation
import Combine

class WordPressService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Public accessors for UI display
    var authenticatedURL: String? {
        baseURL?.absoluteString
    }

    var authenticatedUsername: String? {
        username
    }

    private let baseURLKey = "wordpressBaseURL"
    private let usernameKey = "wordpressUsername"
    private let tokenKey = "wordpressToken"

    private var baseURL: URL?
    private var username: String?
    private var token: String?
    private var authorizationEndpoint: String?

    init() {
        loadCredentials()
    }

    private func loadCredentials() {
        let defaults = UserDefaults.standard

        if let baseURLString = defaults.string(forKey: baseURLKey),
           let url = URL(string: baseURLString) {
            baseURL = url
        }

        username = defaults.string(forKey: usernameKey)
        token = defaults.string(forKey: tokenKey)

        isAuthenticated = token != nil && baseURL != nil && username != nil
    }

    func startAuthentication(baseURL: String) async throws -> URL {
        // Validate and clean the URL
        var cleanBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Automatically upgrade HTTP to HTTPS for security
        if cleanBaseURL.hasPrefix("http://") {
            cleanBaseURL = cleanBaseURL.replacingOccurrences(of: "http://", with: "https://")
        } else if !cleanBaseURL.hasPrefix("https://") {
            cleanBaseURL = "https://" + cleanBaseURL
        }

        guard let url = URL(string: cleanBaseURL) else {
            throw WordPressError.invalidURL
        }

        // Provide helpful feedback for local development
        if url.host?.hasSuffix(".local") == true {
            print("Connecting to local development domain: \(url.absoluteString)")
            print("Note: .local domains may have slower DNS resolution - this is normal for development environments")
        }

        self.baseURL = url

        // Check if application passwords are supported
        try await checkApplicationPasswordSupport()

        // Generate authorization URL
        return try generateAuthorizationURL()
    }

    func authenticate(baseURL: String, username: String, password: String) async throws {
        guard let url = URL(string: baseURL) else {
            throw WordPressError.invalidURL
        }

        self.baseURL = url
        self.username = username

        // Create application password token
        let credentials = "\(username):\(password)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw WordPressError.invalidCredentials
        }

        let base64Credentials = credentialsData.base64EncodedString()
        self.token = "Basic \(base64Credentials)"

        // Test the authentication
        try await testAuthentication()

        // Save credentials
        saveCredentials()

        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.errorMessage = nil
        }
    }

    private func checkApplicationPasswordSupport() async throws {
        guard let baseURL = baseURL else {
            throw WordPressError.notAuthenticated
        }

        let apiRootURL = baseURL.appendingPathComponent("wp-json/")

        var request = URLRequest(url: apiRootURL)
        request.timeoutInterval = 45 // Increased timeout for local development
        request.setValue("WordUp/1.0 API Client by George Stephanis", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log basic response info
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
            }

            // Log the raw response data
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response:")
                print(responseString)
            } else {
                print("API Response: (binary data, \(data.count) bytes)")
            }

        guard response is HTTPURLResponse else {
            throw WordPressError.networkError("Invalid response type")
        }

        // Parse the response to check for authentication endpoints
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WordPressError.networkError("Invalid JSON response")
        }

        guard let authentication = json["authentication"] as? [String: Any] else {
            throw WordPressError.networkError("No authentication information found")
        }

        guard let applicationPasswords = authentication["application-passwords"] as? [String: Any] else {
            throw WordPressError.networkError("Application passwords not supported on this site")
        }

        guard let endpoints = applicationPasswords["endpoints"] as? [String: Any],
              let authorizationURLString = endpoints["authorization"] as? String else {
            throw WordPressError.networkError("Application password authorization endpoint not found")
        }

            // Store the authorization endpoint
            self.authorizationEndpoint = authorizationURLString
        } catch let urlError as URLError {
            print("Network error during application password check: \(urlError.localizedDescription)")
            print("Error code: \(urlError.code.rawValue)")
            switch urlError.code {
            case .cannotFindHost:
                if baseURL.host?.hasSuffix(".local") == true {
                    throw WordPressError.networkError("Cannot find .local domain. Ensure your local development server is running and DNS is configured correctly. For MAMP/XAMPP, check that the virtual host is set up properly.")
                } else {
                    throw WordPressError.networkError("Cannot find host. Check the URL and your network connection.")
                }
            case .cannotConnectToHost:
                throw WordPressError.networkError("Cannot connect to host. Make sure the server is running and accessible.")
            case .timedOut:
                if baseURL.host?.hasSuffix(".local") == true {
                    throw WordPressError.networkError("Connection timed out. Local development servers can be slow - try increasing server timeouts or check if the server is overloaded.")
                } else {
                    throw WordPressError.networkError("Connection timed out. Check your network or server status.")
                }
            case .secureConnectionFailed:
                throw WordPressError.networkError("SSL/TLS connection failed. For local development, ensure your certificate is valid or use HTTP instead of HTTPS.")
            case .dnsLookupFailed:
                throw WordPressError.networkError("DNS lookup failed. Check your DNS settings and network configuration.")
            case .notConnectedToInternet:
                throw WordPressError.networkError("No internet connection detected.")
            default:
                throw WordPressError.networkError("Network error: \(urlError.localizedDescription)")
            }
        } catch {
            print("Unexpected error during application password check: \(error)")
            throw WordPressError.networkError("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func generateAuthorizationURL() throws -> URL {
        guard let _ = baseURL,
              let authorizationEndpoint = authorizationEndpoint else {
            throw WordPressError.notAuthenticated
        }

        let authURL = URL(string: authorizationEndpoint)!
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!

        // Generate a unique app ID
        let appID = UUID().uuidString.lowercased()

        components.queryItems = [
            URLQueryItem(name: "app_name", value: "WordUp"),
            URLQueryItem(name: "app_id", value: appID),
            URLQueryItem(name: "success_url", value: "wordup://auth")
        ]

        guard let finalURL = components.url else {
            throw WordPressError.networkError("Failed to generate authorization URL")
        }

        return finalURL
    }

    private func testAuthentication() async throws {
        guard let baseURL = baseURL,
              let token = token else {
            throw WordPressError.notAuthenticated
        }

        let testURL = baseURL.appendingPathComponent("wp-json/wp/v2/users/me")

        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WordUp/1.0 API Client by George Stephanis", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30 // Increase timeout for local development

        do {
            // Source - https://stackoverflow.com/a
            // Posted by Naoise Golden, modified by community. See post 'Timeline' for change history
            // Retrieved 2025-12-05, License - CC BY-SA 4.0

            let (data, response) = try await URLSession.shared.data(for: request)

            // Log basic response info
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
            }

            // Log the raw response data
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response:")
                print(responseString)
            } else {
                print("API Response: (binary data, \(data.count) bytes)")
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WordPressError.networkError("Invalid response type")
            }

            print("Authentication test response status: \(httpResponse.statusCode)")

            if (200...299).contains(httpResponse.statusCode) {
                // Success
                return
            } else if httpResponse.statusCode == 401 {
                throw WordPressError.authenticationFailed
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Authentication failed with response: \(responseString)")
                }
                throw WordPressError.networkError("HTTP \(httpResponse.statusCode)")
            }
        } catch let urlError as URLError {
            print("URL Error: \(urlError.localizedDescription)")
            switch urlError.code {
            case .cannotFindHost:
                throw WordPressError.networkError("Cannot find host. Check the URL and your network connection.")
            case .cannotConnectToHost:
                throw WordPressError.networkError("Cannot connect to host. Make sure the server is running and accessible.")
            case .timedOut:
                throw WordPressError.networkError("Connection timed out. Check your network or server status.")
            case .secureConnectionFailed:
                throw WordPressError.networkError("SSL/TLS connection failed. For local development, ensure your certificate is valid or use HTTP.")
            default:
                throw WordPressError.networkError("Network error: \(urlError.localizedDescription)")
            }
        } catch {
            print("Unexpected error during authentication: \(error)")
            throw WordPressError.networkError("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func saveCredentials() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL?.absoluteString, forKey: baseURLKey)
        defaults.set(username, forKey: usernameKey)
        defaults.set(token, forKey: tokenKey)
    }

    func signOut() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: baseURLKey)
        defaults.removeObject(forKey: usernameKey)
        defaults.removeObject(forKey: tokenKey)

        baseURL = nil
        username = nil
        token = nil

        isAuthenticated = false
        errorMessage = nil
    }

    func verifyAuthentication() async throws {
        guard isAuthenticated else {
            throw WordPressError.notAuthenticated
        }

        // Test the current authentication by calling the users/me endpoint
        try await testAuthentication()
    }

    func uploadFile(_ fileURL: URL) async throws -> String {
        guard let baseURL = baseURL,
              let token = token else {
            throw WordPressError.notAuthenticated
        }

        let uploadURL = baseURL.appendingPathComponent("wp-json/wp/v2/media")

        // Get file data
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mimeType = getMimeType(for: fileURL.pathExtension)

        // Create multipart form data
        let boundary = UUID().uuidString.lowercased()
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")
        request.setValue("WordUp/1.0 API Client by George Stephanis", forHTTPHeaderField: "User-Agent")

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log basic response info
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status: \(httpResponse.statusCode)")
        }

        // Log the raw response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("API Response:")
            print(responseString)
        } else {
            print("API Response: (binary data, \(data.count) bytes)")
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                print("Upload failed with status code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
            throw WordPressError.uploadFailed
        }

        // Parse response to get media URL
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else {
            throw WordPressError.invalidResponse
        }

        // Return the media URL
        if let sourceURL = json["source_url"] as? String {
            return sourceURL
        }

        // Fallback: construct URL from base URL and ID
        return "\(baseURL.absoluteString)/wp-admin/upload.php?item=\(id)"
    }

    private func getMimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        default:
            return "application/octet-stream"
        }
    }
}

enum WordPressError: Error {
    case invalidURL
    case invalidCredentials
    case authenticationFailed
    case notAuthenticated
    case uploadFailed
    case invalidResponse
    case networkError(String)
}
