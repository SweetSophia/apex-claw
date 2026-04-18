# ClawDeck API Reference

Base path: `/api/v1`

This document is a practical API reference for the current Rails JSON API.
It is based on the live route table and controller behavior in the codebase.

## Authentication

ClawDeck supports two bearer-token modes:

1. **User API token**
   - authenticates as a user
   - used for owner/admin actions like creating tasks, listing boards, enqueueing commands, updating agent settings

2. **Agent token**
   - authenticates as a specific registered agent
   - used for heartbeat, task polling, claiming, command polling, handoffs, and artifact access

Header format:

```http
Authorization: Bearer <token>
```

Optional user-token identity headers:

```http
X-Agent-Name: Cyberlogis
X-Agent-Emoji: 🤖
```

These headers update the user-facing agent identity when using a **user token**. They do not override identity for authenticated agent-token flows.

## Response conventions

- success responses are JSON unless otherwise noted
- SSE uses `text/event-stream`
- some polling endpoints return `204 No Content` when there is nothing to do
- error shape is typically:

```json
{ "error": "message" }
```

---

## Agents

### POST `/agents/register`
Register a new agent using a join token.

Auth: none

Request:
```json
{
  "join_token": "jt_xxx",
  "agent": {
    "name": "builder-1",
    "hostname": "builder-1.local",
    "host_uid": "abc-123",
    "platform": "linux-amd64",
    "version": "0.1.0",
    "tags": ["build", "nightly"],
    "metadata": { "region": "eu-central" }
  }
}
```

Success: `201 Created`
```json
{
  "agent": {
    "id": 12,
    "user_id": 1,
    "name": "builder-1",
    "status": "offline",
    "hostname": "builder-1.local",
    "host_uid": "abc-123",
    "platform": "linux-amd64",
    "version": "0.1.0",
    "tags": ["build", "nightly"],
    "metadata": { "region": "eu-central" },
    "last_heartbeat_at": null,
    "created_at": "2026-04-18T16:00:00Z",
    "updated_at": "2026-04-18T16:00:00Z"
  },
  "agent_token": "agt_xxx"
}
```

Notes:
- join tokens are single-use
- registering multiple agents requires multiple join tokens

---

### POST `/agents/:id/heartbeat`
Update agent liveness and runtime metadata.

Auth: agent token, self only

Request:
```json
{
  "status": "online",
  "version": "0.2.0",
  "platform": "linux-amd64",
  "metadata": {
    "task_runner_active": true,
    "uptime_seconds": 123,
    "draining": false
  }
}
```

Success: `200 OK`
```json
{
  "agent": { "id": 12, "status": "online" },
  "desired_state": { "action": "none" },
  "token_rotation_required": false
}
```

Notes:
- `status` defaults to `online` if omitted
- current implementation always returns `desired_state.action = "none"`

---

### POST `/agents/:id/rotate_token`
Rotate an agent token.

Auth: user owner token

Success: `201 Created`
```json
{
  "agent": { "id": 12 },
  "agent_token": "agt_new_xxx"
}
```

---

### POST `/agents/:id/revoke_token`
Revoke all active tokens for an agent.

Auth: user owner token

Success: `200 OK`
```json
{
  "agent": { "id": 12 },
  "revoked_tokens": 1
}
```

---

### GET `/agents`
List the current user’s agents.

Auth: user token or in-scope agent token

---

### GET `/agents/:id`
Show one agent.

Auth: owner scope

---

### PATCH `/agents/:id`
Update safe agent fields.

Auth: owner scope

Request body:
```json
{
  "agent": {
    "name": "builder-1",
    "status": "disabled",
    "tags": ["nightly"],
    "metadata": { "role": "worker" }
  }
}
```

Permitted fields:
- `name`
- `status`
- `tags`
- `metadata`

---

## Agent Rate Limits

### GET `/agents/:agent_id/rate_limit`
Show rate-limit config for one agent.

Auth: owner user token

### PATCH `/agents/:agent_id/rate_limit`
Update rate-limit config.

Auth: owner user token

Request:
```json
{
  "agent_rate_limit": {
    "window_seconds": 60,
    "max_requests": 120
  }
}
```

---

## Agent Commands

### POST `/agents/:id/commands`
Enqueue a command for an agent.

Auth: owner or admin user token

Request params:
```json
{
  "kind": "drain",
  "payload": { "reason": "maintenance" }
}
```

Command states:
- `pending`
- `acknowledged`
- `completed`
- `failed`

---

### GET `/agent_commands/next`
Poll next pending command for the current agent.

Auth: agent token

Behavior:
- returns the oldest pending command
- atomically transitions it to `acknowledged`
- returns `204` if none exist

---

### PATCH `/agent_commands/:id/ack`
Acknowledge a pending command.

Auth: owning agent token

Requires current state: `pending`

---

### PATCH `/agent_commands/:id/complete`
Complete an acknowledged command.

Auth: owning agent token

Request:
```json
{
  "result": {
    "success": true,
    "message": "Drained"
  }
}
```

Requires current state: `acknowledged`

---

## Boards

### GET `/boards`
List boards for the current user.

### GET `/boards/:id`
Show one board.

Optional query:
- `include_tasks=true`

### POST `/boards`
Create board.

### PATCH `/boards/:id`
Update board.

### DELETE `/boards/:id`
Delete board.

Notes:
- deleting the only board is rejected

---

## Tasks

### GET `/tasks`
List tasks.

Auth: user or agent token in user scope

Supported filters:
- `board_id`
- `status`
- `blocked`
- `tag`
- `completed`
- `priority`
- `assigned`

---

### GET `/tasks/next`
Get the next task for the current agent.

Auth: agent token

Behavior:
- requires `agent_auto_mode`
- returns `204` when no task is available
- returns `204` for draining agents
- claims the task and moves it to `in_progress`
- uses `FOR UPDATE SKIP LOCKED`

Selection rules:
- must be `up_next`
- must be unblocked
- must not already be claimed
- if assigned, must be assigned to the current agent

---

### GET `/tasks/pending_attention`
List tasks that are `in_progress` and currently agent-claimed.

Auth: user or agent token in user scope

---

### POST `/tasks`
Create a task.

Auth: user token

Request:
```json
{
  "task": {
    "name": "Investigate flaky deploy",
    "description": "Look at failed nightly deploys",
    "priority": "high",
    "status": "inbox",
    "board_id": 1,
    "tags": ["ops", "investigation"]
  }
}
```

Notes:
- task creation does **not** accept agent ownership fields like `assigned_agent_id` or `claimed_by_agent_id`
- if no board is provided, the user’s first board is used, or a default board is created

---

### GET `/tasks/:id`
Show one task.

### PATCH `/tasks/:id`
Update a task.

Permitted fields:
- `name`
- `description`
- `priority`
- `due_date`
- `status`
- `blocked`
- `board_id`
- `output`
- `tags`

Optional top-level field:
- `activity_note`

---

### DELETE `/tasks/:id`
Delete a task.

---

### PATCH `/tasks/:id/claim`
Claim a task as the current agent and move it to `in_progress`.

Auth: agent token

---

### PATCH `/tasks/:id/unclaim`
Release claim ownership.

Auth: agent token

---

### PATCH `/tasks/:id/assign`
Mark task as assigned to agent workflow.

Auth: user token in scope

### PATCH `/tasks/:id/unassign`
Remove assignment flag.

Auth: user token in scope

---

### PATCH `/tasks/:id/complete`
Toggle task between `done` and `inbox`.

Auth: user or agent token in scope

Optional output payload:
```json
{
  "task": {
    "output": "Implemented fix and added tests"
  }
}
```

---

## Task Handoffs

### POST `/tasks/:id/handoff`
Create a handoff to another agent.

Auth: agent token

Request:
```json
{
  "to_agent_id": 34,
  "context": "Please continue with the final deploy steps",
  "auto_accept": false
}
```

Rules:
- only the assigned or claiming agent may initiate
- only one pending handoff may exist per task
- if `auto_accept=true`, the target assignment happens immediately

---

### GET `/task_handoffs`
List handoffs relevant to current agent.

Auth: agent token

Optional filters:
- `status`
- `task_id`
- `limit`
- `offset`

---

### PATCH `/task_handoffs/:id/accept`
Accept a pending handoff.

Auth: target agent token

Effect:
- marks handoff accepted
- reassigns and reclaims the task to target agent

---

### PATCH `/task_handoffs/:id/reject`
Reject a pending handoff.

Auth: target agent token

---

## Task Artifacts

### GET `/tasks/:task_id/artifacts`
List task artifacts.

Auth:
- task owner user token, or
- agent token for the assigned or claiming agent

---

### POST `/tasks/:task_id/artifacts`
Upload an artifact.

Auth:
- task owner user token, or
- agent token for the assigned or claiming agent

Request type:
- `multipart/form-data`

Fields:
- `file` (required)
- `metadata` (optional JSON string)

Limits:
- max upload size: `25 MB`

Success: `201 Created`
```json
{
  "id": 1,
  "filename": "report.txt",
  "content_type": "text/plain",
  "size": 123,
  "metadata": { "source": "agent" },
  "created_at": "2026-04-18T16:00:00Z",
  "updated_at": "2026-04-18T16:00:00Z"
}
```

---

### GET `/tasks/:task_id/artifacts/:artifact_id`
Download an artifact.

Auth:
- task owner user token, or
- agent token for the assigned or claiming agent

Response:
- streamed file body
- `Content-Disposition: attachment`

---

## Audit Logs

### GET `/audit_logs`
List audit logs.

Auth: admin user token

Optional filters:
- `actor_type`
- `actor_id`
- `resource_type`
- `resource_id`
- `action` or `audit_action`
- `page`
- `per_page`

---

## Settings

### GET `/settings`
Get current user agent settings.

### PATCH `/settings`
Update current user agent settings.

Fields:
- `agent_name`
- `agent_emoji`
- `agent_auto_mode`

---

## Events (SSE)

### GET `/events`
Open a server-sent events stream.

Auth: authenticated user scope

Response content type:
```http
text/event-stream
```

Observed event types:
- `connection.established`
- `heartbeat`
- `task.created`
- `task.updated`
- `task.completed`
- `task.claimed`
- `task.assigned`

---

## Status enums

### Agent status
- `offline`
- `online`
- `draining`
- `disabled`

### Task status
- `inbox`
- `up_next`
- `in_progress`
- `in_review`
- `done`

### Agent command state
- `pending`
- `acknowledged`
- `completed`
- `failed`

### Task handoff status
- `pending`
- `accepted`
- `rejected`
- `expired`

---

## Notes on current behavior

- JSONB-backed API fields may come back stringified in some responses, especially in integration tests. Be careful asserting exact types for nested metadata and result values.
- `Task` uses a default scope for ordering, so aggregate queries should use `unscoped` plus `reorder(nil)` when doing grouped stats work.
- The Go client already covers registration, heartbeats, task polling, commands, handoffs, and artifact upload. See `docs/sdk/GO_AGENT_SDK.md`.
