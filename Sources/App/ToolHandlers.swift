import Foundation
import MCP

/// Stateless functions that implement each MCP tool.
/// Extracted from main.swift so tests can call them without starting the server.
enum ToolHandlers {

    // MARK: - health_check

    static func healthCheck() -> CallTool.Result {
        CallTool.Result(content: [.text("Reminders MCP server is running.")])
    }

    // MARK: - list_reminders

    static func listReminders(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        // Optional limit: must be a positive integer if provided.
        let limit: Int?
        if let limitValue = args["limit"] {
            guard let n = limitValue.intValue, n > 0 else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'limit' must be a positive integer.")],
                    isError: true
                )
            }
            limit = n
        } else {
            limit = nil
        }

        do {
            let reminders = try await service.listReminders(limit: limit)
            if reminders.isEmpty {
                return CallTool.Result(content: [.text("No incomplete reminders found.")])
            }
            let json = try jsonString(reminders)
            let header = limit != nil ? "Showing up to \(limit!) reminders:\n" : ""
            return CallTool.Result(content: [.text(header + json)])
        } catch {
            return CallTool.Result(
                content: [.text("Error listing reminders: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - create_reminder

    static func createReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        // title is required.
        guard let titleValue = args["title"],
              let title = titleValue.stringValue,
              !title.isEmpty
        else {
            return CallTool.Result(
                content: [.text("Missing required argument: title")],
                isError: true
            )
        }

        // notes — optional string.
        let notes = args["notes"]?.stringValue

        // due_date — optional ISO 8601 string.
        let dueDate: Date?
        if let dueDateValue = args["due_date"] {
            guard let dateString = dueDateValue.stringValue,
                  let parsed = ISO8601DateFormatter().date(from: dateString)
            else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'due_date' must be an ISO 8601 datetime string (e.g. \"2026-03-01T09:00:00Z\").")],
                    isError: true
                )
            }
            dueDate = parsed
        } else {
            dueDate = nil
        }

        // priority — optional string, defaults to none.
        let priority: Priority
        if let priorityValue = args["priority"] {
            guard let raw = priorityValue.stringValue,
                  let parsed = Priority(rawValue: raw)
            else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'priority' must be one of: none, low, medium, high.")],
                    isError: true
                )
            }
            priority = parsed
        } else {
            priority = .none
        }

        // list — optional string.
        let list = args["list"]?.stringValue

        do {
            let reminder = try await service.createReminder(
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                list: list
            )
            let json = try jsonString(reminder)
            return CallTool.Result(content: [.text("Reminder created:\n\(json)")])
        } catch {
            return CallTool.Result(
                content: [.text("Error creating reminder: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}

// MARK: - Helpers

/// Encodes any Encodable value to a pretty-printed JSON string.
func jsonString<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}
