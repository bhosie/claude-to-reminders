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
        // limit
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

        // completed
        let completed: Bool?
        if let completedValue = args["completed"] {
            guard let b = completedValue.boolValue else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'completed' must be a boolean.")],
                    isError: true
                )
            }
            completed = b
        } else {
            completed = nil
        }

        // priority
        let priority: Priority?
        if let priorityValue = args["priority"] {
            guard let raw = priorityValue.stringValue, let p = Priority(rawValue: raw) else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'priority' must be one of: none, low, medium, high.")],
                    isError: true
                )
            }
            priority = p
        } else {
            priority = nil
        }

        // due_before / due_after
        let dueBefore: Date?
        if let v = args["due_before"] {
            guard let s = v.stringValue, let d = ISO8601DateFormatter().date(from: s) else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'due_before' must be an ISO 8601 datetime string.")],
                    isError: true
                )
            }
            dueBefore = d
        } else {
            dueBefore = nil
        }

        let dueAfter: Date?
        if let v = args["due_after"] {
            guard let s = v.stringValue, let d = ISO8601DateFormatter().date(from: s) else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'due_after' must be an ISO 8601 datetime string.")],
                    isError: true
                )
            }
            dueAfter = d
        } else {
            dueAfter = nil
        }

        // query / list (plain strings, no validation needed)
        let query = args["query"]?.stringValue
        let list = args["list"]?.stringValue

        let wantCompleted = completed == true

        do {
            let reminders = try await service.listReminders(
                limit: limit,
                query: query,
                completed: completed,
                priority: priority,
                list: list,
                dueBefore: dueBefore,
                dueAfter: dueAfter
            )
            if reminders.isEmpty {
                let state = wantCompleted ? "completed" : "incomplete"
                return CallTool.Result(content: [.text("No \(state) reminders found matching your filters.")])
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

    // MARK: - get_reminder

    static func getReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        guard let id = args["id"]?.stringValue, !id.isEmpty else {
            return CallTool.Result(
                content: [.text("Missing required argument: id")],
                isError: true
            )
        }
        do {
            let reminder = try await service.getReminder(id: id)
            let json = try jsonString(reminder)
            return CallTool.Result(content: [.text(json)])
        } catch {
            return CallTool.Result(
                content: [.text("Error getting reminder: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - create_reminder

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

        let notes = args["notes"]?.stringValue

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

    // MARK: - update_reminder

    static func updateReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        guard let id = args["id"]?.stringValue, !id.isEmpty else {
            return CallTool.Result(
                content: [.text("Missing required argument: id")],
                isError: true
            )
        }

        let title = args["title"]?.stringValue
        let notes = args["notes"]?.stringValue
        let list = args["list"]?.stringValue

        let dueDate: Date?
        if let dueDateValue = args["due_date"] {
            guard let dateString = dueDateValue.stringValue,
                  let parsed = ISO8601DateFormatter().date(from: dateString)
            else {
                return CallTool.Result(
                    content: [.text("Invalid argument: 'due_date' must be an ISO 8601 datetime string.")],
                    isError: true
                )
            }
            dueDate = parsed
        } else {
            dueDate = nil
        }

        let priority: Priority?
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
            priority = nil
        }

        do {
            let reminder = try await service.updateReminder(
                id: id,
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                list: list
            )
            let json = try jsonString(reminder)
            return CallTool.Result(content: [.text("Reminder updated:\n\(json)")])
        } catch {
            return CallTool.Result(
                content: [.text("Error updating reminder: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - complete_reminder

    static func completeReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        guard let id = args["id"]?.stringValue, !id.isEmpty else {
            return CallTool.Result(
                content: [.text("Missing required argument: id")],
                isError: true
            )
        }
        do {
            let reminder = try await service.completeReminder(id: id)
            return CallTool.Result(content: [.text("Reminder \"\(reminder.title)\" marked as complete.")])
        } catch {
            return CallTool.Result(
                content: [.text("Error completing reminder: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - delete_reminder

    static func deleteReminder(
        args: [String: Value],
        service: any RemindersService
    ) async -> CallTool.Result {
        guard let id = args["id"]?.stringValue, !id.isEmpty else {
            return CallTool.Result(
                content: [.text("Missing required argument: id")],
                isError: true
            )
        }
        do {
            try await service.deleteReminder(id: id)
            return CallTool.Result(content: [.text("Reminder deleted.")])
        } catch {
            return CallTool.Result(
                content: [.text("Error deleting reminder: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - list_reminder_lists

    static func listReminderLists(
        service: any RemindersService
    ) async -> CallTool.Result {
        do {
            let lists = try await service.listReminderLists()
            if lists.isEmpty {
                return CallTool.Result(content: [.text("No reminder lists found.")])
            }
            let json = try jsonString(lists)
            return CallTool.Result(content: [.text(json)])
        } catch {
            return CallTool.Result(
                content: [.text("Error listing reminder lists: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    // MARK: - create_reminder_list

    static func createReminderList(
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
            let list = try await service.createReminderList(title: title)
            let json = try jsonString(list)
            return CallTool.Result(content: [.text("Reminder list created:\n\(json)")])
        } catch {
            return CallTool.Result(
                content: [.text("Error creating reminder list: \(error.localizedDescription)")],
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
