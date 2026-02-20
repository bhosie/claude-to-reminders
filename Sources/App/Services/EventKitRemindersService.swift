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

    func listReminders() async throws -> [ReminderDTO] {
        try await requestAccess()

        let calendars = store.calendars(for: .reminder)
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: calendars)
            store.fetchReminders(matching: predicate) { ekReminders in
                guard let ekReminders else {
                    continuation.resume(returning: [])
                    return
                }
                let dtos = ekReminders
                    .filter { !$0.isCompleted }
                    .map { ReminderDTO(from: $0) }
                continuation.resume(returning: dtos)
            }
        }
    }

    func createReminder(title: String) async throws -> ReminderDTO {
        try await requestAccess()

        guard let defaultCalendar = store.defaultCalendarForNewReminders() else {
            throw ServiceError.noDefaultList
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = defaultCalendar

        try store.save(reminder, commit: true)
        return ReminderDTO(from: reminder)
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

private extension ReminderDTO {
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
