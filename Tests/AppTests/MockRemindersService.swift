import Foundation
@testable import App

/// In-memory mock for unit testing tool handlers without EventKit or permissions.
final class MockRemindersService: RemindersService, @unchecked Sendable {
    private(set) var reminders: [String: ReminderDTO] = [:]
    private(set) var lists: [String: ReminderListDTO] = [
        "default": ReminderListDTO(id: "default", title: "Reminders", isDefault: true)
    ]

    var listError: Error?
    var createError: Error?
    var getError: Error?
    var updateError: Error?
    var completeError: Error?
    var deleteError: Error?
    var listListsError: Error?
    var createListError: Error?
    var deleteListError: Error?

    func listReminders(
        limit: Int?,
        query: String?,
        completed: Bool?,
        priority: Priority?,
        list: String?,
        dueBefore: Date?,
        dueAfter: Date?
    ) async throws -> [ReminderDTO] {
        if let error = listError { throw error }

        let wantCompleted = completed == true
        var results = Array(reminders.values)
            .filter { $0.completed == wantCompleted }

        if let query, !query.isEmpty {
            let q = query.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(q) ||
                ($0.notes?.lowercased().contains(q) ?? false)
            }
        }
        if let priority {
            results = results.filter { $0.priority == priority }
        }
        if let dueAfter {
            results = results.filter { $0.dueDate.map { $0 >= dueAfter } ?? false }
        }
        if let dueBefore {
            results = results.filter { $0.dueDate.map { $0 <= dueBefore } ?? false }
        }
        if let list, !list.isEmpty {
            results = results.filter { $0.list.lowercased() == list.lowercased() }
        }
        if let limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    func getReminder(id: String) async throws -> ReminderDTO {
        if let error = getError { throw error }
        guard let reminder = reminders[id] else { throw MockError.notFound(id) }
        return reminder
    }

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Priority,
        list: String?
    ) async throws -> ReminderDTO {
        if let error = createError { throw error }
        let dto = ReminderDTO(
            id: UUID().uuidString,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            list: list ?? "Reminders",
            completed: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        reminders[dto.id] = dto
        return dto
    }

    func updateReminder(
        id: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        priority: Priority?,
        list: String?
    ) async throws -> ReminderDTO {
        if let error = updateError { throw error }
        guard let existing = reminders[id] else { throw MockError.notFound(id) }
        let updated = ReminderDTO(
            id: existing.id,
            title: title ?? existing.title,
            notes: notes ?? existing.notes,
            dueDate: dueDate ?? existing.dueDate,
            priority: priority ?? existing.priority,
            list: list ?? existing.list,
            completed: existing.completed,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        reminders[id] = updated
        return updated
    }

    func completeReminder(id: String) async throws -> ReminderDTO {
        if let error = completeError { throw error }
        guard let existing = reminders[id] else { throw MockError.notFound(id) }
        let updated = ReminderDTO(
            id: existing.id,
            title: existing.title,
            notes: existing.notes,
            dueDate: existing.dueDate,
            priority: existing.priority,
            list: existing.list,
            completed: true,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        reminders[id] = updated
        return updated
    }

    func deleteReminder(id: String) async throws {
        if let error = deleteError { throw error }
        guard reminders[id] != nil else { throw MockError.notFound(id) }
        reminders.removeValue(forKey: id)
    }

    func listReminderLists() async throws -> [ReminderListDTO] {
        if let error = listListsError { throw error }
        return Array(lists.values).sorted { $0.title < $1.title }
    }

    func createReminderList(title: String) async throws -> ReminderListDTO {
        if let error = createListError { throw error }
        let dto = ReminderListDTO(id: UUID().uuidString, title: title, isDefault: false)
        lists[dto.id] = dto
        return dto
    }

    func deleteReminderList(id: String) async throws {
        if let error = deleteListError { throw error }
        guard let list = lists[id] else { throw MockError.listNotFound(id) }
        guard !list.isDefault else { throw MockError.cannotDeleteDefault }
        lists.removeValue(forKey: id)
    }

    enum MockError: Error, LocalizedError {
        case notFound(String)
        case listNotFound(String)
        case cannotDeleteDefault
        var errorDescription: String? {
            switch self {
            case .notFound(let id):    return "Reminder not found with ID: \(id)"
            case .listNotFound(let id): return "Reminder list not found with ID: \(id)"
            case .cannotDeleteDefault: return "Cannot delete the default reminder list."
            }
        }
    }
}
