//
//  LogManager.swift
//  WordUp
//
//  Created by George Stephanis on 12/15/25.
//

import Foundation
import Combine

struct LogEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let method: String
    let url: String
    let requestHeaders: [String: String]?
    let requestBody: String?
    let responseStatus: Int?
    let responseHeaders: [String: String]?
    let responseBody: String?
    let duration: TimeInterval?
    let error: String?

    init(method: String, url: String, requestHeaders: [String: String]? = nil, requestBody: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.method = method
        self.url = url
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatus = nil
        self.responseHeaders = nil
        self.responseBody = nil
        self.duration = nil
        self.error = nil
    }

    private init(id: UUID, timestamp: Date, method: String, url: String, requestHeaders: [String: String]?, requestBody: String?, responseStatus: Int?, responseHeaders: [String: String]?, responseBody: String?, duration: TimeInterval?, error: String?) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatus = responseStatus
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.duration = duration
        self.error = error
    }

    func withResponse(status: Int, headers: [String: String]?, body: String?, duration: TimeInterval) -> LogEntry {
        return LogEntry(
            id: id,
            timestamp: timestamp,
            method: method,
            url: url,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            responseStatus: status,
            responseHeaders: headers,
            responseBody: body,
            duration: duration,
            error: error
        )
    }

    func withError(_ error: String, duration: TimeInterval? = nil) -> LogEntry {
        return LogEntry(
            id: id,
            timestamp: timestamp,
            method: method,
            url: url,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            responseStatus: responseStatus,
            responseHeaders: responseHeaders,
            responseBody: responseBody,
            duration: duration,
            error: error
        )
    }

    // Sanitize sensitive data before logging
    private func sanitizeHeaders(_ headers: [String: String]?) -> [String: String]? {
        guard var sanitized = headers else { return nil }

        // Remove or mask sensitive headers
        if sanitized["Authorization"] != nil {
            sanitized["Authorization"] = "***"
        }

        return sanitized
    }

    var sanitizedRequestHeaders: [String: String]? {
        return sanitizeHeaders(requestHeaders)
    }

    var sanitizedResponseHeaders: [String: String]? {
        return sanitizeHeaders(responseHeaders)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

class LogManager: ObservableObject {
    @Published var entries: [LogEntry] = []
    private let maxEntries = 100 // Keep only the last 100 entries

    static let shared = LogManager()

    private init() {
        loadLogs()
    }

    func logRequest(method: String, url: String, headers: [String: String]? = nil, body: String? = nil) -> LogEntry {
        let entry = LogEntry(method: method, url: url, requestHeaders: headers, requestBody: body)
        addEntry(entry)
        return entry
    }

    func logResponse(for entry: LogEntry, status: Int, headers: [String: String]?, body: String?, duration: TimeInterval) {
        let responseEntry = entry.withResponse(status: status, headers: headers, body: body, duration: duration)
        updateEntry(responseEntry)
    }

    func logError(for entry: LogEntry, error: String, duration: TimeInterval? = nil) {
        let errorEntry = entry.withError(error, duration: duration)
        updateEntry(errorEntry)
    }

    private func addEntry(_ entry: LogEntry) {
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0) // Insert at beginning for reverse chronological order

            // Keep only the last maxEntries
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }

            self.saveLogs()
        }
    }

    private func updateEntry(_ updatedEntry: LogEntry) {
        DispatchQueue.main.async {
            if let index = self.entries.firstIndex(where: { $0.id == updatedEntry.id }) {
                self.entries[index] = updatedEntry
                self.saveLogs()
            }
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.saveLogs()
        }
    }

    private func saveLogs() {
        do {
            let data = try JSONEncoder().encode(entries)
            let url = getLogFileURL()
            try data.write(to: url)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }

    private func loadLogs() {
        do {
            let url = getLogFileURL()
            let data = try Data(contentsOf: url)
            entries = try JSONDecoder().decode([LogEntry].self, from: data)
        } catch {
            // No existing logs or failed to load - that's OK
            entries = []
        }
    }

    private func getLogFileURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("WordUp")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        return appDirectory.appendingPathComponent("api_logs.json")
    }
}
