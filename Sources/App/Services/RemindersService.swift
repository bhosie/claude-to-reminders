import Foundation

/// The mockable seam between tool handlers and EventKit.
/// All business logic in main.swift calls this protocol — never EventKit directly.
protocol RemindersService: Sendable {
    /// Returns reminders. Pass `limit` to cap the number returned (nil = all).
    func listReminders(limit: Int?) async throws -> [ReminderDTO]

    /// Creates a reminder with the given fields and returns the created reminder.
    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Priority,
        list: String?
    ) async throws -> ReminderDTO
}
