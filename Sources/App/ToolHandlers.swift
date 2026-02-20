import Foundation
import MCP

/// Stateless functions that implement each MCP tool.
/// Extracted from main.swift so tests can call them without starting the server.
enum ToolHandlers {

    static func healthCheck() -> CallTool.Result {
        CallTool.Result(content: [.text("Reminders MCP server is running.")])
    }

    static func listReminders(service: any RemindersService) async -> CallTool.Result {
        do {
            let reminders = try await service.listReminders()
            if reminders.isEmpty {
                return CallTool.Result(content: [.text("No incomplete reminders found.")])
            }
            let json = try jsonString(reminders)
            return CallTool.Result(content: [.text(json)])
        } catch {
            return CallTool.Result(
                content: [.text("Error listing reminders: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    static func createReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        guard let titleValue = args["title"],
              let title = titleValue.stringValue,
              !title.isEmpty
        else {
            return CallTool.Result(
                content: [.text("Missing required argument: title")],
                isError: true
            )
        }
        do {
            let reminder = try await service.createReminder(title: title)
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
