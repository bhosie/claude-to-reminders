import Foundation
import MCP

// MARK: - Server setup

let service: any RemindersService = EventKitRemindersService()

let server = Server(
    name: "reminders-middleware",
    version: "0.1.0",
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
    description: "List all incomplete reminders from Apple Reminders.",
    inputSchema: .object(["type": .string("object"), "properties": .object([:])])
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
        return await ToolHandlers.listReminders(service: service)
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
