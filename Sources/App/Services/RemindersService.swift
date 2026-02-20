import Foundation

/// The mockable seam between tool handlers and EventKit.
/// All business logic in main.swift calls this protocol — never EventKit directly.
protocol RemindersService: Sendable {
    /// Returns reminders. Pass `limit` to cap the number returned (nil = all).
    func listReminders(limit: Int?) async throws -> [ReminderDTO]

    /// Returns a single reminder by its EventKit identifier.
    func getReminder(id: String) async throws -> ReminderDTO

    /// Creates a reminder with the given fields and returns the created reminder.
    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Priority,
        list: String?
    ) async throws -> ReminderDTO

    /// Updates fields on an existing reminder. Only non-nil arguments are applied.
    func updateReminder(
        id: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        priority: Priority?,
        list: String?
    ) async throws -> ReminderDTO

    /// Marks a reminder as completed.
    func completeReminder(id: String) async throws -> ReminderDTO

    /// Permanently deletes a reminder.
    func deleteReminder(id: String) async throws
}
