# Go Agent SDK Guide

The Go agent client lives in:

- `agent/internal/apexclaw/client.go`
- `agent/internal/apexclaw/types.go`

It wraps the ClawDeck `/api/v1` surface used by the bundled agent runtime.

## What the client already supports

### Registration and identity
- `NewClient(baseURL string)`
- `SetToken(token string)`
- `SetAgentID(id int64)`
- `AgentID() int64`
- `Register(joinToken string, info AgentInfo)`

### Liveness
- `Heartbeat(agentID int64, status string, metadata map[string]any)`
- `RotateToken(ctx context.Context)`

### Task flow
- `GetNextTask()`
- `ClaimTask(taskID int64)`
- `UpdateTask(taskID int64, updates TaskUpdateRequest)`
- `CompleteTask(taskID int64, output string)`

### Artifacts
- `UploadArtifact(ctx context.Context, taskID int64, filename string, data io.Reader)`

### Commands
- `GetNextCommand()`
- `AckCommand(commandID int64)`
- `CompleteCommand(commandID int64, result map[string]any)`

### Handoffs
- `HandoffTask(ctx context.Context, taskID int64, targetAgentID int64, handoffContext string)`
- `GetPendingHandoffs(ctx context.Context)`
- `AcceptHandoff(ctx context.Context, handoffID int64)`
- `RejectHandoff(ctx context.Context, handoffID int64)`

---

## Core types

Important response models in `types.go`:
- `Agent`
- `Task`
- `Command`
- `TaskArtifact`
- `TaskHandoff`
- `HeartbeatResponse`
- `RotateTokenResponse`

These match the Rails JSON API closely.

## Basic example: register then heartbeat

```go
package main

import (
	"log"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func main() {
	client := clawdeck.NewClient("http://localhost:3000")

	resp, err := client.Register("jt_example", clawdeck.AgentInfo{
		Name:     "builder-1",
		Hostname: "builder-1.local",
		HostUID:  "abc-123",
		Platform: "linux-amd64",
		Version:  "0.1.0",
		Tags:     []string{"build"},
		Metadata: map[string]string{"region": "eu-central"},
	})
	if err != nil {
		log.Fatal(err)
	}

	_, err = client.Heartbeat(resp.Agent.ID, "online", map[string]any{
		"task_runner_active": false,
		"uptime_seconds":     3,
	})
	if err != nil {
		log.Fatal(err)
	}
}
```

---

## Task polling example

```go
client.SetToken(agentToken)
client.SetAgentID(agentID)

task, err := client.GetNextTask()
if err != nil {
	log.Fatal(err)
}
if task == nil {
	log.Println("no work available")
	return
}

log.Printf("working task %d: %s", task.ID, task.Name)

_, err = client.CompleteTask(task.ID, "finished successfully")
if err != nil {
	log.Fatal(err)
}
```

Notes:
- `GetNextTask()` returns `nil, nil` when the API returns `204 No Content`
- `CompleteTask()` sends `task.output` only when a non-empty string is supplied

---

## Command polling example

```go
cmd, err := client.GetNextCommand()
if err != nil {
	log.Fatal(err)
}
if cmd == nil {
	return
}

_, err = client.AckCommand(cmd.ID)
if err != nil {
	log.Fatal(err)
}

result := map[string]any{"success": true}
_, err = client.CompleteCommand(cmd.ID, result)
if err != nil {
	log.Fatal(err)
}
```

---

## Artifact upload example

```go
file, err := os.Open("artifact.txt")
if err != nil {
	log.Fatal(err)
}
defer file.Close()

artifact, err := client.UploadArtifact(context.Background(), taskID, "artifact.txt", file)
if err != nil {
	log.Fatal(err)
}

log.Printf("uploaded artifact %d (%s)", artifact.ID, artifact.Filename)
```

Important behavior:
- filename is sanitized with `filepath.Base`
- upload is capped at `25 MB`
- upload is context-aware and stops on cancellation

---

## Handoff example

```go
handoff, err := client.HandoffTask(context.Background(), taskID, targetAgentID, "please take over deployment")
if err != nil {
	log.Fatal(err)
}

log.Printf("handoff %d status=%s", handoff.ID, handoff.Status)
```

Accept or reject later:

```go
pending, err := client.GetPendingHandoffs(context.Background())
if err != nil {
	log.Fatal(err)
}

for _, h := range pending {
	_, err := client.AcceptHandoff(context.Background(), h.ID)
	if err != nil {
		log.Fatal(err)
	}
}
```

---

## Error handling notes

The client normalizes most API failures to Go `error`s using the API status code and response body.

Special case:
- `204 No Content` becomes an internal `noContentError`, which is converted into `nil` results by methods like `GetNextTask()` and `GetNextCommand()`.

---

## Runtime usage in the bundled agent

The bundled agent entrypoint is:
- `agent/cmd/claw-agent/main.go`

That runtime already wires:
- persistent token loading
- registration fallback via join token
- heartbeat runner
- task runner
- command runner
- graceful shutdown on SIGINT / SIGTERM

## Recommended next SDK improvements

These are not required for current use, but would strengthen the SDK:
- explicit methods for board and task creation workflows
- richer typed request / response models for settings and rate limits
- helper for SSE consumption if non-Rails clients want live events
- example package or sample agent app outside internal package boundaries


## Load testing note

Agent registration uses **single-use join tokens**.
If you want to register multiple agents in one run, generate one join token per agent.
The concurrency smoke test at `script/loadtest/agent_concurrency_smoke.rb` expects that model.
