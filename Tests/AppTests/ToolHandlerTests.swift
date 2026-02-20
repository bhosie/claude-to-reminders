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
        let result = await ToolHandlers.listReminders(service: mock)
        #expect(result.isError != true)
        #expect(result.content.first?.textValue?.contains("No incomplete reminders") == true)
    }

    @Test("returns JSON when reminders exist")
    func nonEmptyList() async throws {
        let mock = MockRemindersService()
        _ = try await mock.createReminder(title: "Buy milk")
        _ = try await mock.createReminder(title: "Call dentist")

        let result = await ToolHandlers.listReminders(service: mock)
        #expect(result.isError != true)
        let text = result.content.first?.textValue ?? ""
        #expect(text.contains("Buy milk"))
        #expect(text.contains("Call dentist"))
    }

    @Test("returns error result when service throws")
    func serviceError() async {
        let mock = MockRemindersService()
        mock.listError = TestError.intentional
        let result = await ToolHandlers.listReminders(service: mock)
        #expect(result.isError == true)
        #expect(result.content.first?.textValue?.contains("Error") == true)
    }
}

// MARK: - create_reminder

@Suite("create_reminder tool")
struct CreateReminderTests {
    @Test("creates reminder and returns JSON")
    func createsReminder() async {
        let mock = MockRemindersService()
        let args: [String: Value] = ["title": .string("Walk the dog")]
        let result = await ToolHandlers.createReminder(args: args, service: mock)
        #expect(result.isError != true)
        let text = result.content.first?.textValue ?? ""
        #expect(text.contains("Walk the dog"))
        #expect(mock.reminders.count == 1)
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
    @Test("stores created reminders")
    func storesReminders() async throws {
        let mock = MockRemindersService()
        let r1 = try await mock.createReminder(title: "First")
        let r2 = try await mock.createReminder(title: "Second")
        #expect(mock.reminders.count == 2)
        #expect(r1.id != r2.id)
        #expect(r1.title == "First")
        #expect(r2.title == "Second")
    }

    @Test("list returns all stored reminders")
    func listReturnsAll() async throws {
        let mock = MockRemindersService()
        _ = try await mock.createReminder(title: "A")
        _ = try await mock.createReminder(title: "B")
        let list = try await mock.listReminders()
        #expect(list.count == 2)
    }
}

// MARK: - Helpers

private enum TestError: Error {
    case intentional
}

private extension Tool.Content {
    var textValue: String? {
        if case .text(let s) = self { return s }
        return nil
    }
}
