//
//  LogsView.swift
//  WordUp
//
//  Created by George Stephanis on 12/15/25.
//

import SwiftUI

struct LogsView: View {
    @StateObject private var logManager = LogManager.shared
    @State private var selectedEntry: LogEntry?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredEntries: [LogEntry] {
        if searchText.isEmpty {
            return logManager.entries
        } else {
            return logManager.entries.filter { entry in
                entry.url.localizedCaseInsensitiveContains(searchText) ||
                entry.method.localizedCaseInsensitiveContains(searchText) ||
                (entry.responseStatus?.description.contains(searchText) ?? false) ||
                (entry.error?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and buttons
            HStack {
                Text("API Logs")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if !logManager.entries.isEmpty {
                    Button("Clear All") {
                        logManager.clearLogs()
                        selectedEntry = nil
                    }
                    .foregroundColor(.red)
                }

                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor).opacity(0.8))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Logs list
                VStack {
                    List(filteredEntries, selection: $selectedEntry) { entry in
                        LogEntryRow(entry: entry)
                            .tag(entry)
                    }
                    .listStyle(.inset)
                }
                .frame(minWidth: 400)

                Divider()

                // Log details
                VStack {
                    if let entry = selectedEntry {
                        LogDetailView(entry: entry)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Select a log entry to view details")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 300)
                .padding()
            }
        }
        .frame(width: 800, height: 600)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Method and URL
            VStack(alignment: .leading) {
                HStack {
                    Text(entry.method)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(width: 50, alignment: .leading)

                    Text(entry.url)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Status and timing
                HStack {
                    if let status = entry.responseStatus {
                        Text("\(status)")
                            .font(.caption)
                            .foregroundColor(LogEntryRow.statusColor(for: status))
                    } else if entry.error != nil {
                        Text("Error")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if let duration = entry.duration {
                        Text(String(format: "%.2fs", duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if let status = entry.responseStatus {
            return LogEntryRow.statusColor(for: status)
        } else if entry.error != nil {
            return .red
        } else {
            return .orange
        }
    }

    static func statusColor(for status: Int) -> Color {
        switch status {
        case 200...299:
            return .green
        case 300...399:
            return .blue
        case 400...499:
            return .orange
        case 500...599:
            return .red
        default:
            return .gray
        }
    }
}

struct LogDetailView: View {
    let entry: LogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Request info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request")
                        .font(.headline)

                    HStack {
                        Text("Method:")
                        Text(entry.method)
                            .font(.system(.body, design: .monospaced))
                    }

                    HStack {
                        Text("URL:")
                        Text(entry.url)
                            .textSelection(.enabled)
                    }

                    if let headers = entry.sanitizedRequestHeaders, !headers.isEmpty {
                        DisclosureGroup("Headers") {
                            ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key + ":")
                                        .font(.system(.caption, design: .monospaced))
                                    Text(value)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }

                    if let body = entry.requestBody {
                        DisclosureGroup("Body") {
                            Text(body)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Divider()

                // Response info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response")
                        .font(.headline)

                    if let status = entry.responseStatus {
                        HStack {
                            Text("Status:")
                            Text("\(status)")
                                .foregroundColor(LogEntryRow.statusColor(for: status))
                        }
                    }

                    if let duration = entry.duration {
                        HStack {
                            Text("Duration:")
                            Text(String(format: "%.3f seconds", duration))
                        }
                    }

                    if let error = entry.error {
                        HStack {
                            Text("Error:")
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }

                    if let headers = entry.sanitizedResponseHeaders, !headers.isEmpty {
                        DisclosureGroup("Headers") {
                            ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key + ":")
                                        .font(.system(.caption, design: .monospaced))
                                    Text(value)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }

                    if let body = entry.responseBody {
                        DisclosureGroup("Body") {
                            Text(body)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LogsView()
}

