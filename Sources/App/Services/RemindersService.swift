import Foundation

/// The mockable seam between tool handlers and EventKit.
/// All business logic in main.swift calls this protocol — never EventKit directly.
protocol RemindersService: Sendable {
    /// Returns all reminders from the default list.
    func listReminders() async throws -> [ReminderDTO]

    /// Creates a reminder with the given title and returns the created reminder.
    func createReminder(title: String) async throws -> ReminderDTO
}
