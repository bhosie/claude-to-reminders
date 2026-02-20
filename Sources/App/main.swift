import Foundation
import MCP

// MARK: - Server setup

let service: any RemindersService = EventKitRemindersService()

let server = Server(
    name: "reminders-middleware",
    version: "0.3.0",
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
    description: "List incomplete reminders from Apple Reminders. Use 'limit' to cap results — always specify a limit when you only need a few reminders.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Maximum number of reminders to return. Omit to return all.")
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
