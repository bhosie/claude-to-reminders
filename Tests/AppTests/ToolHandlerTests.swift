import Foundation
import Testing
import MCP
@testable import App

// MARK: - health_check

@Suite("health_check tool")
struct HealthCheckTests {
    @Test("returns running message")
    func returnsRunningMessage() {
        let result = ToolHandlers.healthCheck()
        #expect(result.isError != true)
        #expect(result.content.first?.textValue?.contains("running") == true)
    }
}

// MARK: - list_reminders

@Suite("list_reminders tool")
struct ListRemindersTests {
    @Test("returns empty message when no reminders")
    func emptyList() async {
        let mock = MockRemindersService()
        let result = await ToolHandlers.listReminders(args: [:], service: mock)
        #expect(result.isError != true)
        #expect(result.content.first?.textValue?.contains("No incomplete reminders") == true)
    }

    @Test("returns JSON when reminders exist")
    func nonEmptyList() async throws {
        let mock = MockRemindersService()
        _ = try await mock.createReminder(title: "Buy milk", notes: nil, dueDate: nil, priority: .none, list: nil)
        _ = try await mock.createReminder(title: "Call dentist", notes: nil, dueDate: nil, priority: .none, list: nil)

        let result = await ToolHandlers.listReminders(args: [:], service: mock)
        #expect(result.isError != true)
        let text = result.content.first?.textValue ?? ""
        #expect(text.contains("Buy milk"))
        #expect(text.contains("Call dentist"))
    }

    @Test("limit caps the number of results")
    func limitCapsResults() async throws {
        let mock = MockRemindersService()
        for i in 1...5 {
            _ = try await mock.createReminder(title: "Reminder \(i)", notes: nil, dueDate: nil, priority: .none, list: nil)
        }
        let result = await ToolHandlers.listReminders(args: ["limit": Value.int(3)], service: mock)
        #expect(result.isError != true)
        // Decode result and verify count
        let text = result.content.first?.textValue ?? ""
        #expect(text.contains("Showing up to 3 reminders"))
    }

    @Test("invalid limit returns error")
    func invalidLimit() async {
        let mock = MockRemindersService()
        let result = await ToolHandlers.listReminders(args: ["limit": Value.int(-1)], service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("positive integer") == true)
    }

    @Test("returns error result when service throws")
    func serviceError() async {
        let mock = MockRemindersService()
        mock.listError = TestError.intentional
        let result = await ToolHandlers.listReminders(args: [:], service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("Error") == true)
    }
}

// MARK: - create_reminder

@Suite("create_reminder tool")
struct CreateReminderTests {
    @Test("creates reminder with title only")
    func createsWithTitleOnly() async {
        let mock = MockRemindersService()
        let args: [String: Value] = ["title": .string("Walk the dog")]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError != true)
        let text = result.content.first?.textValue ?? ""
        #expect(text.contains("Walk the dog"))
        #expect(mock.reminders.count == 1)
    }

    @Test("creates reminder with all fields")
    func createsWithAllFields() async throws {
        let mock = MockRemindersService()
        let args: [String: Value] = [
            "title": .string("Q3 report"),
            "notes": .string("Check revenue section"),
            "due_date": .string("2026-03-01T09:00:00Z"),
            "priority": .string("high"),
            "list": .string("Work")
        ]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError != true)
        let reminder = mock.reminders.values.first
        #expect(reminder?.title == "Q3 report")
        #expect(reminder?.notes == "Check revenue section")
        #expect(reminder?.priority == .high)
        #expect(reminder?.list == "Work")
        #expect(reminder?.dueDate != nil)
    }

    @Test("returns error when title is missing")
    func missingTitle() async {
        let mock = MockRemindersService()
        let result = await ToolHandlers.createReminder(args: [:], service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("Missing required argument") == true)
        #expect(mock.reminders.isEmpty)
    }

    @Test("returns error when title is empty string")
    func emptyTitle() async {
        let mock = MockRemindersService()
        let args: [String: Value] = ["title": .string("")]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError == true)
        #expect(mock.reminders.isEmpty)
    }

    @Test("returns error for invalid due_date format")
    func invalidDueDate() async {
        let mock = MockRemindersService()
        let args: [String: Value] = [
            "title": .string("Test"),
            "due_date": .string("not-a-date")
        ]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("ISO 8601") == true)
        #expect(mock.reminders.isEmpty)
    }

    @Test("returns error for invalid priority value")
    func invalidPriority() async {
        let mock = MockRemindersService()
        let args: [String: Value] = [
            "title": .string("Test"),
            "priority": .string("urgent")
        ]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("priority") == true)
        #expect(mock.reminders.isEmpty)
    }

    @Test("returns error result when service throws")
    func serviceError() async {
        let mock = MockRemindersService()
        mock.createError = TestError.intentional
        let args: [String: Value] = ["title": .string("Test")]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("Error") == true)
    }
}

// MARK: - MockRemindersService

@Suite("MockRemindersService")
struct MockRemindersServiceTests {
    @Test("stores created reminders with all fields")
    func storesAllFields() async throws {
        let mock = MockRemindersService()
        let due = Date()
        let r = try await mock.createReminder(
            title: "Test",
            notes: "Some notes",
            dueDate: due,
            priority: .medium,
            list: "Work"
        )
        #expect(r.title == "Test")
        #expect(r.notes == "Some notes")
        #expect(r.priority == .medium)
        #expect(r.list == "Work")
        #expect(r.dueDate != nil)
    }

    @Test("limit is respected by listReminders")
    func limitRespected() async throws {
        let mock = MockRemindersService()
        for i in 1...10 {
            _ = try await mock.createReminder(title: "Item \(i)", notes: nil, dueDate: nil, priority: .none, list: nil)
        }
        let all = try await mock.listReminders(limit: nil)
        let limited = try await mock.listReminders(limit: 4)
        #expect(all.count == 10)
        #expect(limited.count == 4)
    }

    @Test("default list is Reminders when not specified")
    func defaultList() async throws {
        let mock = MockRemindersService()
        let r = try await mock.createReminder(title: "X", notes: nil, dueDate: nil, priority: .none, list: nil)
        #expect(r.list == "Reminders")
    }
}

// MARK: - Priority mapping

@Suite("Priority")
struct PriorityTests {
    @Test("EK round-trip: high")
    func highRoundTrip() {
        #expect(Priority(ekValue: Priority.high.ekValue) == .high)
    }
    @Test("EK round-trip: medium")
    func mediumRoundTrip() {
        #expect(Priority(ekValue: Priority.medium.ekValue) == .medium)
    }
    @Test("EK round-trip: low")
    func lowRoundTrip() {
        #expect(Priority(ekValue: Priority.low.ekValue) == .low)
    }
    @Test("EK round-trip: none")
    func noneRoundTrip() {
        #expect(Priority(ekValue: Priority.none.ekValue) == .none)
    }
    @Test("unknown EK value maps to none")
    func unknownMapsToNone() {
        #expect(Priority(ekValue: 99) == .none)
    }
}

// MARK: - Helpers

private enum TestError: Error {
    case intentional
}

extension Tool.Content {
    var textValue: String? {
        if case .text(let s) = self { return s }
        return nil
    }
}

