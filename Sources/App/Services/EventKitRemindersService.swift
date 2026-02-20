@preconcurrency import EventKit
import Foundation

/// Real implementation of RemindersService backed by Apple's EventKit.
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
        guard granted else { throw ServiceError.permissionDenied }
    }

    // MARK: - RemindersService

    func listReminders(
        limit: Int?,
        query: String?,
        completed: Bool?,
        priority: Priority?,
        list: String?,
        dueBefore: Date?,
        dueAfter: Date?
    ) async throws -> [ReminderDTO] {
        try await requestAccess()

        // Narrow to a specific calendar if a list name is provided.
        let calendars: [EKCalendar]
        if let list, !list.isEmpty, let cal = namedCalendar(list) {
            calendars = [cal]
        } else {
            calendars = store.calendars(for: .reminder)
        }

        // Use the appropriate EventKit predicate based on completion filter.
        let wantCompleted = completed == true

        return try await withCheckedThrowingContinuation { continuation in
            let predicate: NSPredicate
            if wantCompleted {
                predicate = store.predicateForCompletedReminders(
                    withCompletionDateStarting: nil, ending: nil, calendars: calendars)
            } else {
                predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil, ending: nil, calendars: calendars)
            }

            store.fetchReminders(matching: predicate) { ekReminders in
                guard let ekReminders else {
                    continuation.resume(returning: [])
                    return
                }

                var results = ekReminders.map { ReminderDTO(from: $0) }

                // In-memory filters
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
                if let limit {
                    results = Array(results.prefix(limit))
                }

                continuation.resume(returning: results)
            }
        }
    }

    func getReminder(id: String) async throws -> ReminderDTO {
        try await requestAccess()
        return ReminderDTO(from: try fetchReminder(id: id))
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
        try store.remove(try fetchReminder(id: id), commit: true)
    }

    func listReminderLists() async throws -> [ReminderListDTO] {
        try await requestAccess()
        let defaultID = store.defaultCalendarForNewReminders()?.calendarIdentifier
        return store.calendars(for: .reminder).map {
            ReminderListDTO(id: $0.calendarIdentifier, title: $0.title, isDefault: $0.calendarIdentifier == defaultID)
        }
    }

    func deleteReminderList(id: String) async throws {
        try await requestAccess()
        guard let calendar = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == id }) else {
            throw ServiceError.reminderListNotFound(id)
        }
        guard calendar.calendarIdentifier != store.defaultCalendarForNewReminders()?.calendarIdentifier else {
            throw ServiceError.cannotDeleteDefaultList
        }
        try store.removeCalendar(calendar, commit: true)
    }

    func createReminderList(title: String) async throws -> ReminderListDTO {
        try await requestAccess()
        guard let source = store.defaultCalendarForNewReminders()?.source else {
            throw ServiceError.noDefaultList
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = title
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        let defaultID = store.defaultCalendarForNewReminders()?.calendarIdentifier
        return ReminderListDTO(id: calendar.calendarIdentifier, title: calendar.title, isDefault: calendar.calendarIdentifier == defaultID)
    }

    // MARK: - Helpers

    private func fetchReminder(id: String) throws -> EKReminder {
        guard let item = store.calendarItem(withIdentifier: id),
              let reminder = item as? EKReminder
        else { throw ServiceError.reminderNotFound(id) }
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
        case reminderListNotFound(String)
        case cannotDeleteDefaultList

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Access to Reminders was denied. Grant access in System Settings > Privacy & Security > Reminders."
            case .noDefaultList:
                return "No default Reminders list found. Open Reminders.app and ensure at least one list exists."
            case .reminderNotFound(let id):
                return "Reminder not found with ID: \(id)"
            case .reminderListNotFound(let id):
                return "Reminder list not found with ID: \(id)"
            case .cannotDeleteDefaultList:
                return "Cannot delete the default reminder list."
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
