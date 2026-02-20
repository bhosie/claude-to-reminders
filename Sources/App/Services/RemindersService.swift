import Foundation

/// The mockable seam between tool handlers and EventKit.
/// All business logic in main.swift calls this protocol — never EventKit directly.
protocol RemindersService: Sendable {
    /// Returns reminders with optional filtering.
    /// - Parameters:
    ///   - limit: Cap the number returned (nil = all).
    ///   - query: Case-insensitive text search across title and notes.
    ///   - completed: nil = incomplete only (default), true = completed only.
    ///   - priority: Filter to a specific priority level.
    ///   - list: Filter to a specific list name.
    ///   - dueBefore: Only include reminders due before this date.
    ///   - dueAfter: Only include reminders due after this date.
    func listReminders(
        limit: Int?,
        query: String?,
        completed: Bool?,
        priority: Priority?,
        list: String?,
        dueBefore: Date?,
        dueAfter: Date?
    ) async throws -> [ReminderDTO]

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

    /// Returns all reminder lists.
    func listReminderLists() async throws -> [ReminderListDTO]

    /// Creates a new reminder list with the given title.
    func createReminderList(title: String) async throws -> ReminderListDTO

    /// Permanently deletes a reminder list by its ID.
    func deleteReminderList(id: String) async throws
}
