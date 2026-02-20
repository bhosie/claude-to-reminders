import Foundation
import MCP

// MARK: - Server setup

let service: any RemindersService = EventKitRemindersService()

let server = Server(
    name: "reminders-middleware",
    version: "0.6.0",
    capabilities: .init(tools: .init(listChanged: false))
)

// MARK: - Tool definitions

let healthCheckTool = Tool(
    name: "health_check",
    description: "Verify that the Reminders MCP server is running.",
    inputSchema: .object(["type": .string("object"), "properties": .object([:])])
)

let listRemindersTool = Tool(
    name: "list_reminders",
    description: "List reminders from Apple Reminders with optional filters. Use 'limit' to cap results — always specify a limit when you only need a few reminders.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Maximum number of reminders to return. Omit to return all.")
            ]),
            "query": .object([
                "type": .string("string"),
                "description": .string("Case-insensitive text search across title and notes.")
            ]),
            "completed": .object([
                "type": .string("boolean"),
                "description": .string("Filter by completion status. Omit (or false) for incomplete reminders, true for completed.")
            ]),
            "priority": .object([
                "type": .string("string"),
                "enum": .array([.string("none"), .string("low"), .string("medium"), .string("high")]),
                "description": .string("Filter to a specific priority level.")
            ]),
            "list": .object([
                "type": .string("string"),
                "description": .string("Filter to a specific reminder list name.")
            ]),
            "due_before": .object([
                "type": .string("string"),
                "description": .string("Only include reminders due before this ISO 8601 datetime.")
            ]),
            "due_after": .object([
                "type": .string("string"),
                "description": .string("Only include reminders due after this ISO 8601 datetime.")
            ])
        ])
    ])
)

let getReminderTool = Tool(
    name: "get_reminder",
    description: "Get the details of a single reminder by its ID.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("The reminder ID (from list_reminders).")
            ])
        ]),
        "required": .array([.string("id")])
    ])
)

let createReminderTool = Tool(
    name: "create_reminder",
    description: "Create a new reminder in Apple Reminders.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object([
                "type": .string("string"),
                "description": .string("The reminder title (required).")
            ]),
            "notes": .object([
                "type": .string("string"),
                "description": .string("Optional notes or additional detail.")
            ]),
            "due_date": .object([
                "type": .string("string"),
                "description": .string("Optional due date as ISO 8601 string (e.g. \"2026-03-01T09:00:00Z\").")
            ]),
            "priority": .object([
                "type": .string("string"),
                "enum": .array([.string("none"), .string("low"), .string("medium"), .string("high")]),
                "description": .string("Optional priority level. Defaults to none.")
            ]),
            "list": .object([
                "type": .string("string"),
                "description": .string("Optional name of the Reminders list to add to. Falls back to the default list if not found.")
            ])
        ]),
        "required": .array([.string("title")])
    ])
)

let updateReminderTool = Tool(
    name: "update_reminder",
    description: "Update fields on an existing reminder. Only the fields you provide are changed.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("The reminder ID (required).")
            ]),
            "title": .object([
                "type": .string("string"),
                "description": .string("New title.")
            ]),
            "notes": .object([
                "type": .string("string"),
                "description": .string("New notes.")
            ]),
            "due_date": .object([
                "type": .string("string"),
                "description": .string("New due date as ISO 8601 string.")
            ]),
            "priority": .object([
                "type": .string("string"),
                "enum": .array([.string("none"), .string("low"), .string("medium"), .string("high")]),
                "description": .string("New priority level.")
            ]),
            "list": .object([
                "type": .string("string"),
                "description": .string("Move reminder to this list name.")
            ])
        ]),
        "required": .array([.string("id")])
    ])
)

let completeReminderTool = Tool(
    name: "complete_reminder",
    description: "Mark a reminder as completed.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("The reminder ID (required).")
            ])
        ]),
        "required": .array([.string("id")])
    ])
)

let deleteReminderTool = Tool(
    name: "delete_reminder",
    description: "Permanently delete a reminder.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("The reminder ID (required).")
            ])
        ]),
        "required": .array([.string("id")])
    ])
)

let listReminderListsTool = Tool(
    name: "list_reminder_lists",
    description: "List all available reminder lists.",
    inputSchema: .object(["type": .string("object"), "properties": .object([:])])
)

let createReminderListTool = Tool(
    name: "create_reminder_list",
    description: "Create a new reminder list.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object([
                "type": .string("string"),
                "description": .string("The name of the new list (required).")
            ])
        ]),
        "required": .array([.string("title")])
    ])
)

let deleteReminderListTool = Tool(
    name: "delete_reminder_list",
    description: "Permanently delete a reminder list and all its reminders. Requires two calls: first without confirm to see a warning, then with confirm: true to execute. Cannot delete the default list.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("The reminder list ID (required). Get it from list_reminder_lists.")
            ]),
            "confirm": .object([
                "type": .string("boolean"),
                "description": .string("Must be true to actually delete. Omit on the first call to see a warning.")
            ])
        ]),
        "required": .array([.string("id")])
    ])
)

let batchCreateRemindersTool = Tool(
    name: "batch_create_reminders",
    description: "Create multiple reminders in one call. Returns created reminders and any failures.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "items": .object([
                "type": .string("array"),
                "description": .string("Array of reminders to create."),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title":    .object(["type": .string("string"), "description": .string("Reminder title (required).")]),
                        "notes":    .object(["type": .string("string"), "description": .string("Optional notes.")]),
                        "due_date": .object(["type": .string("string"), "description": .string("Optional due date (ISO 8601).")]),
                        "priority": .object(["type": .string("string"), "description": .string("none, low, medium, or high.")]),
                        "list":     .object(["type": .string("string"), "description": .string("Optional list name.")])
                    ]),
                    "required": .array([.string("title")])
                ])
            ])
        ]),
        "required": .array([.string("items")])
    ])
)

let batchCompleteRemindersTool = Tool(
    name: "batch_complete_reminders",
    description: "Mark multiple reminders as completed. Returns completed reminders and any failures.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "ids": .object([
                "type": .string("array"),
                "description": .string("Array of reminder IDs to complete."),
                "items": .object(["type": .string("string")])
            ])
        ]),
        "required": .array([.string("ids")])
    ])
)

let batchDeleteRemindersTool = Tool(
    name: "batch_delete_reminders",
    description: "Permanently delete multiple reminders. Returns deleted IDs and any failures.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "ids": .object([
                "type": .string("array"),
                "description": .string("Array of reminder IDs to delete."),
                "items": .object(["type": .string("string")])
            ])
        ]),
        "required": .array([.string("ids")])
    ])
)

// MARK: - Tool list handler

await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: [
        healthCheckTool,
        listRemindersTool,
        getReminderTool,
        createReminderTool,
        updateReminderTool,
        completeReminderTool,
        deleteReminderTool,
        listReminderListsTool,
        createReminderListTool,
        deleteReminderListTool,
        batchCreateRemindersTool,
        batchCompleteRemindersTool,
        batchDeleteRemindersTool,
    ])
}

// MARK: - Tool call handler

await server.withMethodHandler(CallTool.self) { params in
    let args = params.arguments ?? [:]
    switch params.name {
    case "health_check":
        return ToolHandlers.healthCheck()
    case "list_reminders":
        return await ToolHandlers.listReminders(args: args, service: service)
    case "get_reminder":
        return await ToolHandlers.getReminder(args: args, service: service)
    case "create_reminder":
        return await ToolHandlers.createReminder(args: args, service: service)
    case "update_reminder":
        return await ToolHandlers.updateReminder(args: args, service: service)
    case "complete_reminder":
        return await ToolHandlers.completeReminder(args: args, service: service)
    case "delete_reminder":
        return await ToolHandlers.deleteReminder(args: args, service: service)
    case "list_reminder_lists":
        return await ToolHandlers.listReminderLists(service: service)
    case "create_reminder_list":
        return await ToolHandlers.createReminderList(args: args, service: service)
    case "delete_reminder_list":
        return await ToolHandlers.deleteReminderList(args: args, service: service)
    case "batch_create_reminders":
        return await ToolHandlers.batchCreateReminders(args: args, service: service)
    case "batch_complete_reminders":
        return await ToolHandlers.batchCompleteReminders(args: args, service: service)
    case "batch_delete_reminders":
        return await ToolHandlers.batchDeleteReminders(args: args, service: service)
    default:
        return CallTool.Result(
            content: [.text("Unknown tool: \(params.name)")],
            isError: true
        )
    }
}

// MARK: - Start

let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
