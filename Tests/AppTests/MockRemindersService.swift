import Foundation
@testable import App

/// In-memory mock for unit testing tool handlers without EventKit or permissions.
final class MockRemindersService: RemindersService, @unchecked Sendable {
    // Stored reminders, keyed by ID.
    private(set) var reminders: [String: ReminderDTO] = [:]

    // Optionally inject errors to test failure paths.
    var listError: Error?
    var createError: Error?

    func listReminders() async throws -> [ReminderDTO] {
        if let error = listError { throw error }
        return Array(reminders.values)
    }

    func createReminder(title: String) async throws -> ReminderDTO {
        if let error = createError { throw error }
        let dto = ReminderDTO(
            id: UUID().uuidString,
            title: title,
            notes: nil,
            dueDate: nil,
            priority: .none,
            list: "Reminders",
            completed: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        reminders[dto.id] = dto
        return dto
    }
}
