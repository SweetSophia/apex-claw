package clawdeck

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// checkAuth verifies the Authorization header is set correctly.
func checkAuth(t *testing.T, r *http.Request, expected string) {
	t.Helper()
	if auth := r.Header.Get("Authorization"); auth != "Bearer "+expected {
		t.Errorf("expected Authorization 'Bearer %s', got %q", expected, auth)
	}
}

func TestNewClient(t *testing.T) {
	client := NewClient("http://localhost:3000")
	if client.baseURL != "http://localhost:3000" {
		t.Errorf("expected baseURL http://localhost:3000, got %s", client.baseURL)
	}
	if client.token != "" {
		t.Error("expected empty token on new client")
	}
	if client.agentID != 0 {
		t.Error("expected zero agentID on new client")
	}
}

func TestClient_SetToken(t *testing.T) {
	client := NewClient("http://localhost:3000")
	client.SetToken("test-token-123")
	if client.token != "test-token-123" {
		t.Errorf("expected token test-token-123, got %s", client.token)
	}
}

func TestClient_SetAgentID(t *testing.T) {
	client := NewClient("http://localhost:3000")
	client.SetAgentID(42)
	if client.AgentID() != 42 {
		t.Errorf("expected agentID 42, got %d", client.AgentID())
	}
}

func TestClient_Register(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agents/register" {
			t.Errorf("expected /api/v1/agents/register, got %s", r.URL.Path)
		}

		resp := RegisterResponse{
			Agent: Agent{
				ID:     1,
				Name:   "Test Agent",
				Status: "offline",
			},
			AgentToken: "new-agent-token",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	resp, err := client.Register("join-token-abc", AgentInfo{
		Name:     "Test Agent",
		Hostname: "test.local",
		Platform: "linux",
		Version:  "1.0.0",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.AgentToken != "new-agent-token" {
		t.Errorf("expected agent token new-agent-token, got %s", resp.AgentToken)
	}
	if client.token != "new-agent-token" {
		t.Errorf("client token not set after register")
	}
	if client.AgentID() != 1 {
		t.Errorf("expected agent ID 1, got %d", client.AgentID())
	}
}

func TestClient_Heartbeat(t *testing.T) {
	var receivedStatus string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "agent-token")
		if r.Method != "POST" {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agents/5/heartbeat" {
			t.Errorf("expected /api/v1/agents/5/heartbeat, got %s", r.URL.Path)
		}

		var req HeartbeatRequest
		json.NewDecoder(r.Body).Decode(&req)
		receivedStatus = req.Status

		resp := HeartbeatResponse{
			Agent:        Agent{ID: 5, Status: req.Status},
			DesiredState: DesiredState{Action: "none"},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("agent-token")

	resp, err := client.Heartbeat(5, "draining", map[string]any{"load": 0.8})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if receivedStatus != "draining" {
		t.Errorf("expected status draining, got %s", receivedStatus)
	}
	if resp.DesiredState.Action != "none" {
		t.Errorf("expected desired_state action none, got %s", resp.DesiredState.Action)
	}
}

func TestClient_GetNextTask_WithTask(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "GET" {
			t.Errorf("expected GET, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/tasks/next" {
			t.Errorf("expected /api/v1/tasks/next, got %s", r.URL.Path)
		}

		task := Task{ID: 42, Name: "Build feature", Status: "in_progress"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(task)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	task, err := client.GetNextTask()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task == nil {
		t.Fatal("expected task, got nil")
	}
	if task.ID != 42 {
		t.Errorf("expected task ID 42, got %d", task.ID)
	}
	if task.Name != "Build feature" {
		t.Errorf("expected task name 'Build feature', got %s", task.Name)
	}
}

func TestClient_GetNextTask_NoContent(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	task, err := client.GetNextTask()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task != nil {
		t.Errorf("expected nil task for 204, got %+v", task)
	}
}

func TestClient_CompleteTask(t *testing.T) {
	var receivedBody map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "PATCH" {
			t.Errorf("expected PATCH, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/tasks/99/complete" {
			t.Errorf("expected /api/v1/tasks/99/complete, got %s", r.URL.Path)
		}

		if err := json.NewDecoder(r.Body).Decode(&receivedBody); err != nil {
			t.Fatalf("failed to decode request body: %v", err)
		}

		task := Task{ID: 99, Name: "Done task", Status: "done", Output: "Build ok"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(task)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	task, err := client.CompleteTask(99, "Build ok")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task.Status != "done" {
		t.Errorf("expected status done, got %s", task.Status)
	}
	if taskMap, ok := receivedBody["task"].(map[string]any); ok {
		if taskMap["output"] != "Build ok" {
			t.Errorf("expected output 'Build ok' in request, got %v", taskMap["output"])
		}
	} else {
		t.Errorf("expected request body to contain task map, got: %v", receivedBody)
	}
}

func TestClient_CompleteTask_EmptyOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		task := Task{ID: 99, Name: "Done task", Status: "done"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(task)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	task, err := client.CompleteTask(99, "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task.Status != "done" {
		t.Errorf("expected status done, got %s", task.Status)
	}
}

func TestClient_GetNextCommand_WithCommand(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "GET" {
			t.Errorf("expected GET, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agent_commands/next" {
			t.Errorf("expected /api/v1/agent_commands/next, got %s", r.URL.Path)
		}

		cmd := Command{ID: 7, Kind: "drain", State: "acknowledged"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(cmd)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	cmd, err := client.GetNextCommand()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cmd == nil {
		t.Fatal("expected command, got nil")
	}
	if cmd.Kind != "drain" {
		t.Errorf("expected kind drain, got %s", cmd.Kind)
	}
}

func TestClient_GetNextCommand_NoContent(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	cmd, err := client.GetNextCommand()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cmd != nil {
		t.Errorf("expected nil command for 204, got %+v", cmd)
	}
}

func TestClient_AckCommand(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "PATCH" {
			t.Errorf("expected PATCH, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agent_commands/7/ack" {
			t.Errorf("expected /api/v1/agent_commands/7/ack, got %s", r.URL.Path)
		}

		cmd := Command{ID: 7, Kind: "drain", State: "acknowledged"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(cmd)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	cmd, err := client.AckCommand(7)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cmd.State != "acknowledged" {
		t.Errorf("expected state acknowledged, got %s", cmd.State)
	}
}

func TestClient_CompleteCommand(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "PATCH" {
			t.Errorf("expected PATCH, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agent_commands/7/complete" {
			t.Errorf("expected /api/v1/agent_commands/7/complete, got %s", r.URL.Path)
		}

		cmd := Command{ID: 7, Kind: "drain", State: "completed", Result: map[string]any{"success": true}}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(cmd)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	cmd, err := client.CompleteCommand(7, map[string]any{"success": true})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cmd.State != "completed" {
		t.Errorf("expected state completed, got %s", cmd.State)
	}
}

func TestClient_APIError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid token"})
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("bad-token")

	_, err := client.GetNextTask()
	if err == nil {
		t.Fatal("expected error for 401, got nil")
	}
	if err.Error() == "" {
		t.Error("expected non-empty error message")
	}
}

func TestClient_ClaimTask(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "PATCH" {
			t.Errorf("expected PATCH, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/tasks/10/claim" {
			t.Errorf("expected /api/v1/tasks/10/claim, got %s", r.URL.Path)
		}

		task := Task{ID: 10, Name: "Claimed", Status: "in_progress"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(task)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	task, err := client.ClaimTask(10)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task.Status != "in_progress" {
		t.Errorf("expected status in_progress, got %s", task.Status)
	}
}

func TestClient_UpdateTask(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "test-token")
		if r.Method != "PATCH" {
			t.Errorf("expected PATCH, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/tasks/10" {
			t.Errorf("expected /api/v1/tasks/10, got %s", r.URL.Path)
		}

		// Verify request payload (UpdateTask sends flat struct, no "task" wrapper)
		var reqBody map[string]any
		if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
			t.Fatalf("failed to decode request body: %v", err)
		}
		if reqBody["status"] != "in_progress" {
			t.Errorf("expected status 'in_progress' in request, got %v", reqBody["status"])
		}

		task := Task{ID: 10, Name: "Updated", Status: "in_progress"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(task)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("test-token")

	status := "in_progress"
	task, err := client.UpdateTask(10, TaskUpdateRequest{Status: &status})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if task.Name != "Updated" {
		t.Errorf("expected name Updated, got %s", task.Name)
	}
}

func TestNoContentDetection(t *testing.T) {
	err := &noContentError{}
	if !isNoContent(err) {
		t.Error("expected isNoContent to return true for noContentError")
	}
	if isNoContent(nil) {
		t.Error("expected isNoContent to return false for nil")
	}
}

func TestClient_RotateToken(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		checkAuth(t, r, "old-token")
		if r.Method != "POST" {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if r.URL.Path != "/api/v1/agents/5/rotate_token" {
			t.Errorf("expected /api/v1/agents/5/rotate_token, got %s", r.URL.Path)
		}

		resp := RotateTokenResponse{
			Agent:      Agent{ID: 5, Status: "online"},
			AgentToken: "new-rotated-token",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.SetToken("old-token")
	client.SetAgentID(5)

	newToken, err := client.RotateToken(nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newToken != "new-rotated-token" {
		t.Fatalf("expected new token to be updated, got %q", newToken)
	}
	if client.token != "new-rotated-token" {
		t.Fatalf("expected client token to rotate, got %q", client.token)
	}
}
