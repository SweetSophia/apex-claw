package runner

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
)

func TestCommandRunnerPollDispatchAckCompleteFlow(t *testing.T) {
	var acked atomic.Bool
	var completed atomic.Bool
	var result map[string]any

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/agent_commands/next":
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 7, Kind: "health_check", State: "pending", Payload: map[string]any{}})
		case "/api/v1/agent_commands/7/ack":
			acked.Store(true)
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 7, State: "acknowledged"})
		case "/api/v1/agent_commands/7/complete":
			completed.Store(true)
			defer r.Body.Close()
			var req apexclaw.CommandCompleteRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				t.Fatalf("decode complete request: %v", err)
			}
			result = req.Result
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 7, State: "completed", Result: req.Result})
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	client := apexclaw.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(42)

	dispatcher := NewCommandDispatcher()
	dispatcher.Register("health_check", &testCommandHandler{result: map[string]any{"ok": true}})

	runner := NewCommandRunner(client, 10*time.Millisecond, dispatcher)
	ctx, cancel := context.WithTimeout(context.Background(), 80*time.Millisecond)
	defer cancel()

	go runner.Run(ctx)
	<-ctx.Done()

	if !acked.Load() {
		t.Fatal("expected command to be acked")
	}
	if !completed.Load() {
		t.Fatal("expected command to be completed")
	}
	if !result["ok"].(bool) {
		t.Fatalf("expected handler result in completion payload, got %#v", result)
	}
}

func TestCommandRunnerRetriesAck(t *testing.T) {
	var ackAttempts atomic.Int32
	var completed atomic.Bool

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/agent_commands/next":
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 8, Kind: "health_check", State: "pending", Payload: map[string]any{}})
		case "/api/v1/agent_commands/8/ack":
			attempt := ackAttempts.Add(1)
			if attempt < 3 {
				w.WriteHeader(http.StatusBadGateway)
				json.NewEncoder(w).Encode(map[string]any{"error": "try again"})
				return
			}
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 8, State: "acknowledged"})
		case "/api/v1/agent_commands/8/complete":
			completed.Store(true)
			json.NewEncoder(w).Encode(apexclaw.Command{ID: 8, State: "completed"})
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	client := apexclaw.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(42)

	dispatcher := NewCommandDispatcher()
	dispatcher.Register("health_check", &testCommandHandler{result: map[string]any{"ok": true}})

	runner := NewCommandRunner(client, 10*time.Millisecond, dispatcher)
	ctx, cancel := context.WithTimeout(context.Background(), 900*time.Millisecond)
	defer cancel()

	go runner.Run(ctx)
	<-ctx.Done()

	if ackAttempts.Load() < 3 {
		t.Fatalf("expected retries, got %d attempts", ackAttempts.Load())
	}
	if !completed.Load() {
		t.Fatal("expected command completion after ack retry")
	}
}
