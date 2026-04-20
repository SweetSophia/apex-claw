package runner

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/SweetSophia/clawdeck/agent/internal/clawdeck"
)

// --- helpers ---

func newTestHeartbeatRunner(t *testing.T, handler http.HandlerFunc) (*HeartbeatRunner, *clawdeck.Client) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 50*time.Millisecond)
	return hr, client
}

// --- Tests ---

func TestHeartbeatRunner_DrainingDefault(t *testing.T) {
	hr := NewHeartbeatRunner(nil, 1, 0)
	if hr.Draining() {
		t.Fatal("expected draining=false by default")
	}
	hr.SetDraining(true)
	if !hr.Draining() {
		t.Fatal("expected draining=true after set")
	}
}

func TestHeartbeatRunner_NormalizeInterval(t *testing.T) {
	cases := []struct {
		name     string
		input    time.Duration
		expected time.Duration
	}{
		{name: "default when zero", input: 0, expected: defaultHeartbeatInterval},
		{name: "clamp low", input: 2 * time.Second, expected: minHeartbeatInterval},
		{name: "clamp high", input: 10 * time.Minute, expected: maxHeartbeatInterval},
		{name: "keep valid", input: 45 * time.Second, expected: 45 * time.Second},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := normalizeHeartbeatInterval(tc.input); got != tc.expected {
				t.Fatalf("expected %s, got %s", tc.expected, got)
			}
		})
	}
}

func TestHeartbeatRunner_DesiredStateDrain(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := clawdeck.HeartbeatResponse{
			Agent:        clawdeck.Agent{ID: 1, Status: "online"},
			DesiredState: clawdeck.DesiredState{Action: "drain"},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 50*time.Millisecond)

	done := make(chan struct{})
	go func() {
		hr.sendHeartbeat(context.Background())
		close(done)
	}()

	time.Sleep(200 * time.Millisecond)

	if !hr.Draining() {
		t.Fatal("expected draining=true after drain action")
	}
}

func TestHeartbeatRunner_DesiredStateShutdown(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := clawdeck.HeartbeatResponse{
			Agent:        clawdeck.Agent{ID: 1, Status: "online"},
			DesiredState: clawdeck.DesiredState{Action: "shutdown"},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 50*time.Millisecond)

	hr.sendHeartbeat(context.Background())

	select {
	case req := <-hr.ShutdownCh:
		if req.Action != "shutdown" {
			t.Fatalf("expected shutdown, got %s", req.Action)
		}
	case <-time.After(time.Second):
		t.Fatal("expected shutdown request on ShutdownCh")
	}
}

func TestHeartbeatRunner_DesiredStateRestart(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := clawdeck.HeartbeatResponse{
			Agent:        clawdeck.Agent{ID: 1, Status: "online"},
			DesiredState: clawdeck.DesiredState{Action: "restart"},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 50*time.Millisecond)

	hr.sendHeartbeat(context.Background())

	select {
	case req := <-hr.ShutdownCh:
		if req.Action != "restart" {
			t.Fatalf("expected restart, got %s", req.Action)
		}
	case <-time.After(time.Second):
		t.Fatal("expected restart request on ShutdownCh")
	}
}

func TestHeartbeatRunner_MetadataEnrichment(t *testing.T) {
	hr := NewHeartbeatRunner(nil, 1, 0)

	meta := hr.collectMetadata()
	if _, ok := meta["task_runner_active"]; !ok {
		t.Fatal("expected task_runner_active in metadata")
	}
	if _, ok := meta["draining"]; !ok {
		t.Fatal("expected draining in metadata")
	}
	if _, ok := meta["uptime_seconds"]; !ok {
		t.Fatal("expected uptime_seconds in metadata")
	}
	if meta["draining"].(bool) != false {
		t.Fatal("expected draining=false")
	}

	hr.SetTaskActiveFunc(func() bool { return true })
	meta = hr.collectMetadata()
	if !meta["task_runner_active"].(bool) {
		t.Fatal("expected task_runner_active=true")
	}

	hr.SetDraining(true)
	meta = hr.collectMetadata()
	if !meta["draining"].(bool) {
		t.Fatal("expected draining=true")
	}
}

func TestHeartbeatRunner_DesiredStateNone(t *testing.T) {
	hr := NewHeartbeatRunner(nil, 1, 0)
	hr.handleDesiredState("none")
	hr.handleDesiredState("")
	if hr.Draining() {
		t.Fatal("expected no state change for none/empty")
	}
}

func TestHeartbeatRunner_LogsTokenRotationRequirement(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := clawdeck.HeartbeatResponse{
			Agent:                 clawdeck.Agent{ID: 1, Status: "online"},
			DesiredState:          clawdeck.DesiredState{Action: "none"},
			TokenRotationRequired: true,
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 50*time.Millisecond)

	hr.sendHeartbeat(context.Background())

	select {
	case <-hr.ShutdownCh:
		t.Fatal("did not expect shutdown request")
	default:
	}
}

func TestHeartbeatRunner_UpdatesIntervalFromServer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := clawdeck.HeartbeatResponse{
			Agent:                    clawdeck.Agent{ID: 1, Status: "online"},
			DesiredState:             clawdeck.DesiredState{Action: "none"},
			HeartbeatIntervalSeconds: 90,
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := clawdeck.NewClient(srv.URL)
	client.SetToken("test-token")
	client.SetAgentID(1)
	hr := NewHeartbeatRunner(client, 1, 30*time.Second)

	hr.sendHeartbeat(context.Background())

	if got := hr.Interval(); got != 90*time.Second {
		t.Fatalf("expected interval 90s, got %s", got)
	}
}
