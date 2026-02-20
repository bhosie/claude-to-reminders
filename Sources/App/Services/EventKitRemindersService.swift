@preconcurrency import EventKit
import Foundation

/// Real implementation of RemindersService backed by Apple's EventKit.
/// Requests permission on first use and caches the EKEventStore.
final class EventKitRemindersService: RemindersService {
    // EKEventStore is internally thread-safe; @preconcurrency import suppresses the
    // Sendable warning from the Obj-C framework header.
    private let store = EKEventStore()

    // MARK: - Permission

    /// Requests access to reminders if not already granted.
    /// Throws a descriptive error if the user denies access.
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

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Priority,
        list: String?
    ) async throws -> ReminderDTO {
        try await requestAccess()

        // Find the named list, fall back to the default list.
        let calendar = namedCalendar(list) ?? store.defaultCalendarForNewReminders()
        guard let calendar else {
            throw ServiceError.noDefaultList
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        reminder.notes = notes
        reminder.priority = priority.ekValue

        if let dueDate {
            // EventKit stores due dates as DateComponents, not Date.
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
        }

        try store.save(reminder, commit: true)
        return ReminderDTO(from: reminder)
    }

    // MARK: - Helpers

    /// Returns the EKCalendar with the given name, or nil if not found.
    private func namedCalendar(_ name: String?) -> EKCalendar? {
        guard let name, !name.isEmpty else { return nil }
        return store.calendars(for: .reminder)
            .first { $0.title.lowercased() == name.lowercased() }
    }

    // MARK: - Errors

    enum ServiceError: Error, LocalizedError {
        case permissionDenied
        case noDefaultList

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Access to Reminders was denied. Grant access in System Settings > Privacy & Security > Reminders."
            case .noDefaultList:
                return "No default Reminders list found. Open Reminders.app and ensure at least one list exists."
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
