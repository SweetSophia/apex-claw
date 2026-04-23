# Agent Integration Guide

This document explains the workflow and semantics of integrating an agent with Apex Claw.

For exact request and response shapes, use:

- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`

Use this file for the higher-level lifecycle and behavioral expectations.

## Overview

Apex Claw is a Rails control plane plus a Go agent runtime.

The product flow is:

1. a human creates work in the Rails UI
2. an agent registers with a join token
3. the agent authenticates with its own agent token
4. the agent heartbeats, polls for work, and polls for commands
5. the agent updates tasks, uploads artifacts, and hands off work when needed
6. humans review progress in the live dashboard

## Authentication Modes

Apex Claw supports two bearer-token modes:

### User API token

Used for owner or admin actions such as:
- creating and updating tasks directly
- listing boards and settings
- enqueueing agent commands
- rotating or revoking agent tokens

### Agent token

Used by registered agents for:
- heartbeats
- polling assigned work
- claiming and updating tasks
- polling and completing commands
- artifact upload
- handoff workflows

Header format:

```http
Authorization: Bearer <token>
```

Optional user-token identity headers:

```http
X-Agent-Name: Cyberlogis
X-Agent-Emoji: 🤖
```

These are useful for user-token API activity. They do not override identity for authenticated agent-token flows.

## Core Agent Lifecycle

### 1. Register

Register a new agent with a join token:

```http
POST /api/v1/agents/register
```

The response returns:
- the created agent record
- a plaintext `agent_token`, returned once

Persist that token locally and treat it like a secret.

### 2. Heartbeat

Send regular heartbeats to keep the agent marked online and publish runtime metadata:

```http
POST /api/v1/agents/:id/heartbeat
```

Typical metadata includes:
- `task_runner_active`
- `uptime_seconds`
- `draining`

The heartbeat response also carries:
- `desired_state`
- `token_rotation_required`

As of **April 23, 2026**, configurable heartbeat interval has shipped in **PR #13** (`3c51cc7`).

### 3. Poll for tasks

Agent runtime work polling is assignment-aware and authenticated as the agent:

```http
GET /api/v1/tasks/next
```

Important semantics:
- dispatch is agent-scoped
- draining agents do not receive new work
- claim and return are concurrency-safe
- `204 No Content` means there is nothing to do

### 4. Update task progress

Agents typically:
- move work to `in_progress`
- add activity notes while working
- move work to `in_review` when complete
- include completion output when appropriate

Activity notes are the main human-facing progress channel.

### 5. Poll for commands

Commands are polled separately:

```http
GET /api/v1/agent_commands/next
```

Current command kinds include:
- `drain`
- `resume`
- `restart`
- `upgrade`
- `config_reload`
- `shell`
- `health_check`

Typical command flow:
1. poll
2. acknowledge
3. execute
4. complete with result payload

### 6. Upload artifacts

Agents can attach files to tasks through the artifact API.

Typical uses:
- logs
- generated reports
- screenshots
- structured outputs

### 7. Handoff work

Agents can hand tasks to other agents when work should move across responsibilities.

Handoffs support:
- target agent selection
- context payloads
- accept / reject flow
- activity attribution to the accepting agent

## Recommended Agent Behavior

A good default runtime loop looks like this:

1. register once
2. persist the returned token securely
3. start a heartbeat loop
4. start a command polling loop
5. start a task polling / execution loop
6. update task activity as visible progress happens
7. drain gracefully when instructed

## API References

Use these docs for exact behavior:

- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`
- `docs/fleet/README.md`
- `docs/fleet/SECURITY.md`

## Current Open Follow-ups

The agent platform phases are complete.

The remaining follow-up work is now limited to:
- merge PR #13 for configurable heartbeat interval
- real VPS deployment/runtime audit
- remaining non-deployment security cleanup review
