import Foundation

/// Priority levels for reminders, matching EventKit's scale.
enum Priority: String, Codable, Sendable {
    case none
    case low
    case medium
    case high

    /// Maps to EventKit's numeric priority (1–9, 0 = none).
    var ekValue: Int {
        switch self {
        case .none:   return 0
        case .low:    return 9
        case .medium: return 5
        case .high:   return 1
        }
    }

    /// Converts an EventKit numeric priority back to our enum.
    init(ekValue: Int) {
        switch ekValue {
        case 0:        self = .none
        case 1...4:    self = .high
        case 5:        self = .medium
        case 6...9:    self = .low
        default:       self = .none
        }
    }
}

/// The canonical data transfer object for a reminder.
/// Used both as API input/output and as the mock's in-memory model.
struct ReminderDTO: Codable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let priority: Priority
    let list: String
    let completed: Bool
    let createdAt: Date?
    let updatedAt: Date?
}
