@preconcurrency import EventKit
import Foundation

/// Real implementation of RemindersService backed by Apple's EventKit.
/// Requests permission on first use and caches the EKEventStore.
final class EventKitRemindersService: RemindersService {
    // EKEventStore is internally thread-safe; @preconcurrency import suppresses the
    // Sendable warning from the Obj-C framework header.
    private let store = EKEventStore()

    // MARK: - Permission

    private func requestAccess() async throws {
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await store.requestAccess(to: .reminder)
        }
        guard granted else {
            throw ServiceError.permissionDenied
        }
    }

    // MARK: - RemindersService

    func listReminders(limit: Int?) async throws -> [ReminderDTO] {
        try await requestAccess()

        let calendars = store.calendars(for: .reminder)
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: calendars)
            store.fetchReminders(matching: predicate) { ekReminders in
                guard let ekReminders else {
                    continuation.resume(returning: [])
                    return
                }
                var results = ekReminders
                    .filter { !$0.isCompleted }
                    .map { ReminderDTO(from: $0) }
                if let limit {
                    results = Array(results.prefix(limit))
                }
                continuation.resume(returning: results)
            }
        }
    }

    func getReminder(id: String) async throws -> ReminderDTO {
        try await requestAccess()
        let reminder = try fetchReminder(id: id)
        return ReminderDTO(from: reminder)
    }

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Priority,
        list: String?
    ) async throws -> ReminderDTO {
        try await requestAccess()

        let calendar = namedCalendar(list) ?? store.defaultCalendarForNewReminders()
        guard let calendar else { throw ServiceError.noDefaultList }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        reminder.notes = notes
        reminder.priority = priority.ekValue
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dueDate)
        }

        try store.save(reminder, commit: true)
        return ReminderDTO(from: reminder)
    }

    func updateReminder(
        id: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        priority: Priority?,
        list: String?
    ) async throws -> ReminderDTO {
        try await requestAccess()
        let reminder = try fetchReminder(id: id)

        if let title { reminder.title = title }
        if let notes { reminder.notes = notes }
        if let priority { reminder.priority = priority.ekValue }
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dueDate)
        }
        if let list, let calendar = namedCalendar(list) {
            reminder.calendar = calendar
        }

        try store.save(reminder, commit: true)
        return ReminderDTO(from: reminder)
    }

    func completeReminder(id: String) async throws -> ReminderDTO {
        try await requestAccess()
        let reminder = try fetchReminder(id: id)
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try store.save(reminder, commit: true)
        return ReminderDTO(from: reminder)
    }

    func deleteReminder(id: String) async throws {
        try await requestAccess()
        let reminder = try fetchReminder(id: id)
        try store.remove(reminder, commit: true)
    }

    // MARK: - Helpers

    private func fetchReminder(id: String) throws -> EKReminder {
        guard let item = store.calendarItem(withIdentifier: id),
              let reminder = item as? EKReminder
        else {
            throw ServiceError.reminderNotFound(id)
        }
        return reminder
    }

    private func namedCalendar(_ name: String?) -> EKCalendar? {
        guard let name, !name.isEmpty else { return nil }
        return store.calendars(for: .reminder)
            .first { $0.title.lowercased() == name.lowercased() }
    }

    // MARK: - Errors

    enum ServiceError: Error, LocalizedError {
        case permissionDenied
        case noDefaultList
        case reminderNotFound(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Access to Reminders was denied. Grant access in System Settings > Privacy & Security > Reminders."
            case .noDefaultList:
                return "No default Reminders list found. Open Reminders.app and ensure at least one list exists."
            case .reminderNotFound(let id):
                return "Reminder not found with ID: \(id)"
            }
        }
    }
}

// MARK: - EKReminder → ReminderDTO

extension ReminderDTO {
    init(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? ""
        self.notes = reminder.notes
        self.dueDate = reminder.dueDateComponents?.date
        self.priority = Priority(ekValue: reminder.priority)
        self.list = reminder.calendar?.title ?? "Reminders"
        self.completed = reminder.isCompleted
        self.createdAt = reminder.creationDate
        self.updatedAt = reminder.lastModifiedDate
    }
}
