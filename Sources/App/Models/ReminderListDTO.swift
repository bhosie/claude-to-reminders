import Foundation

/// The canonical data transfer object for a reminder list (EKCalendar).
struct ReminderListDTO: Codable, Sendable {
    let id: String
    let title: String
    let isDefault: Bool
}
