import Foundation
import MCP

// MARK: - Server setup

let service: any RemindersService = EventKitRemindersService()

let server = Server(
    name: "reminders-middleware",
    version: "0.2.0",
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

// MARK: - Tool list handler

await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: [healthCheckTool, listRemindersTool, createReminderTool])
}

// MARK: - Tool call handler

await server.withMethodHandler(CallTool.self) { params in
    let args = params.arguments ?? [:]
    switch params.name {
    case "health_check":
        return ToolHandlers.healthCheck()
    case "list_reminders":
        return await ToolHandlers.listReminders(args: args, service: service)
    case "create_reminder":
        return await ToolHandlers.createReminder(args: args, service: service)
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
