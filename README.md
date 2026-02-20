# claude-to-reminders

A Swift MCP (Model Context Protocol) server that gives Claude native access to Apple Reminders via EventKit. Ask Claude to create, list, update, and search your reminders in natural language — changes appear instantly in Reminders.app and sync to all your Apple devices via iCloud.

## How it works

```
You → Claude → MCP (stdio) → Swift server → EventKit → Reminders.app → iCloud
```

Claude treats the tools in this server as first-class capabilities — no prompting or configuration required per conversation.

## Requirements

- macOS 13+
- Xcode 16+ / Swift 6+
- Claude desktop app

## Installation

```bash
git clone https://github.com/bhosie/claude-to-reminders.git
cd claude-to-reminders
./install.sh
```

`install.sh` builds the release binary and registers the MCP server in the Claude desktop app config. Quit and reopen Claude after running it.

**First use:** macOS will prompt for Reminders access. Grant it once and it persists.

## Available tools

| Tool | Description |
|------|-------------|
| `health_check` | Verify the server is running |
| `list_reminders` | List reminders with optional filters: `query`, `completed`, `priority`, `list`, `due_before`, `due_after`, `limit` |
| `get_reminder` | Fetch a single reminder by ID |
| `create_reminder` | Create a reminder with title, notes, due date, priority, and list |
| `update_reminder` | Update any fields on an existing reminder |
| `complete_reminder` | Mark a reminder as completed |
| `delete_reminder` | Permanently delete a reminder |
| `list_reminder_lists` | List all reminder lists |
| `create_reminder_list` | Create a new reminder list |
| `delete_reminder_list` | Delete a reminder list (two-step confirmation required) |
| `batch_create_reminders` | Create multiple reminders in one call |
| `batch_complete_reminders` | Complete multiple reminders by ID |
| `batch_delete_reminders` | Delete multiple reminders by ID |

## Example usage

> "Add a reminder to call the dentist on Friday at 9am"
> "What are my high priority reminders?"
> "Show me everything in my Projects list"
> "Mark all the camping reminders as done"
> "Create reminders for each item on this list..."
> "What lists do I have?"

## Development

```bash
# Run tests
swift test

# Build debug
swift build

# Build release
swift build -c release
```

### Architecture

```
Sources/App/
├── main.swift                          # Server entry point, tool routing
├── ToolHandlers.swift                  # Testable handler logic
├── Models/
│   ├── ReminderDTO.swift               # Reminder data model + Priority enum
│   └── ReminderListDTO.swift           # Reminder list data model
└── Services/
    ├── RemindersService.swift           # Protocol (mockable seam)
    └── EventKitRemindersService.swift   # Real EventKit implementation

Tests/AppTests/
├── MockRemindersService.swift          # In-memory mock, no permissions needed
└── ToolHandlerTests.swift              # 74 unit tests across 15 suites
```

The `RemindersService` protocol is the key architectural seam — tool handlers call the protocol, never EventKit directly. This makes all handler logic unit-testable without device permissions.

## Implementation Plan

| Slice | Status | Description |
|-------|--------|-------------|
| 1 — MVP | ✅ Done | `health_check`, `list_reminders`, `create_reminder` |
| 2 — Rich creation | ✅ Done | Due dates, notes, priority, target list |
| 3 — Update & delete | ✅ Done | Full CRUD lifecycle |
| 4 — Search & filter | ✅ Done | Query by text, date, priority, list |
| 5 — List management | ✅ Done | `list_reminder_lists`, `create_reminder_list` |
| 6 — Batch operations | ✅ Done | `batch_create_reminders`, `batch_complete_reminders`, `batch_delete_reminders` |
| 7 — Delete list | ✅ Done | `delete_reminder_list` |
| 8 — Calendar | ⬜ | Calendar event management via EventKit (future) |

## Privacy

All data stays on-device. The server binds to stdio — it is not a network service and is not accessible from outside your machine.
