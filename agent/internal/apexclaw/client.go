package apexclaw

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
	"time"
)

const MaxArtifactUploadSize int64 = 25 << 20

type Client struct {
	baseURL    string
	httpClient *http.Client
	token      string
	agentID    int64
}

func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *Client) SetToken(token string) {
	c.token = token
}

func (c *Client) SetAgentID(id int64) {
	c.agentID = id
}

func (c *Client) AgentID() int64 {
	return c.agentID
}

func (c *Client) Register(joinToken string, info AgentInfo) (*RegisterResponse, error) {
	req := RegisterRequest{
		JoinToken: joinToken,
		Agent:     info,
	}

	var resp RegisterResponse
	if err := c.doRequest("POST", "/api/v1/agents/register", req, &resp, false); err != nil {
		return nil, fmt.Errorf("register: %w", err)
	}

	c.token = resp.AgentToken
	c.agentID = resp.Agent.ID

	return &resp, nil
}

func (c *Client) Heartbeat(agentID int64, status string, metadata map[string]any) (*HeartbeatResponse, error) {
	req := HeartbeatRequest{
		Status:   status,
		Metadata: metadata,
	}

	var resp HeartbeatResponse
	path := fmt.Sprintf("/api/v1/agents/%d/heartbeat", agentID)
	if err := c.doRequest("POST", path, req, &resp, true); err != nil {
		return nil, fmt.Errorf("heartbeat: %w", err)
	}

	return &resp, nil
}

func (c *Client) RotateToken(ctx context.Context) (string, error) {
	var resp RotateTokenResponse
	path := fmt.Sprintf("/api/v1/agents/%d/rotate_token", c.agentID)
	if err := c.doRequestWithContext(ctx, "POST", path, nil, &resp, true); err != nil {
		return "", fmt.Errorf("rotate token: %w", err)
	}

	c.token = resp.AgentToken
	return resp.AgentToken, nil
}

func (c *Client) GetNextTask() (*Task, error) {
	var resp Task
	if err := c.doRequest("GET", "/api/v1/tasks/next", nil, &resp, true); err != nil {
		if isNoContent(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("get next task: %w", err)
	}
	return &resp, nil
}

func (c *Client) ClaimTask(taskID int64) (*Task, error) {
	var resp Task
	path := fmt.Sprintf("/api/v1/tasks/%d/claim", taskID)
	if err := c.doRequest("PATCH", path, nil, &resp, true); err != nil {
		return nil, fmt.Errorf("claim task: %w", err)
	}
	return &resp, nil
}

func (c *Client) UpdateTask(taskID int64, updates TaskUpdateRequest) (*Task, error) {
	var resp Task
	path := fmt.Sprintf("/api/v1/tasks/%d", taskID)
	if err := c.doRequest("PATCH", path, updates, &resp, true); err != nil {
		return nil, fmt.Errorf("update task: %w", err)
	}
	return &resp, nil
}

func (c *Client) CompleteTask(taskID int64, output string) (*Task, error) {
	var resp Task
	path := fmt.Sprintf("/api/v1/tasks/%d/complete", taskID)

	var reqBody any
	if output != "" {
		reqBody = map[string]any{
			"task": map[string]string{"output": output},
		}
	}

	if err := c.doRequest("PATCH", path, reqBody, &resp, true); err != nil {
		return nil, fmt.Errorf("complete task: %w", err)
	}
	return &resp, nil
}

func (c *Client) UploadArtifact(ctx context.Context, taskID int64, filename string, data io.Reader) (*TaskArtifact, error) {
	filename = sanitizeArtifactFilename(filename)
	if filename == "" {
		return nil, fmt.Errorf("artifact filename is required")
	}

	path := fmt.Sprintf("/api/v1/tasks/%d/artifacts", taskID)
	url := c.baseURL + path

	pr, pw := io.Pipe()
	writer := multipart.NewWriter(pw)
	limitedReader := &io.LimitedReader{R: &contextReader{ctx: ctx, reader: data}, N: MaxArtifactUploadSize + 1}

	go func() {
		defer pw.Close()
		fileWriter, err := writer.CreateFormFile("file", filename)
		if err != nil {
			pw.CloseWithError(fmt.Errorf("create multipart file: %w", err))
			return
		}
		written, err := io.Copy(fileWriter, limitedReader)
		if err != nil {
			pw.CloseWithError(fmt.Errorf("copy multipart file: %w", err))
			return
		}
		if written > MaxArtifactUploadSize {
			pw.CloseWithError(fmt.Errorf("artifact exceeds max upload size of %d bytes", MaxArtifactUploadSize))
			return
		}
		if err := writer.Close(); err != nil {
			pw.CloseWithError(fmt.Errorf("close multipart writer: %w", err))
			return
		}
	}()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, pr)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", writer.FormDataContentType())
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	if resp.StatusCode >= 400 {
		var errResp ErrorResponse
		if json.Unmarshal(respBody, &errResp) == nil && errResp.Error != "" {
			return nil, fmt.Errorf("api error (%d): %s", resp.StatusCode, errResp.Error)
		}
		return nil, fmt.Errorf("api error (%d): %s", resp.StatusCode, string(respBody))
	}

	var artifact TaskArtifact
	if err := json.Unmarshal(respBody, &artifact); err != nil {
		return nil, fmt.Errorf("unmarshaling response: %w", err)
	}

	return &artifact, nil
}

func (c *Client) GetNextCommand() (*Command, error) {
	var resp Command
	if err := c.doRequest("GET", "/api/v1/agent_commands/next", nil, &resp, true); err != nil {
		if isNoContent(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("get next command: %w", err)
	}
	return &resp, nil
}

func (c *Client) AckCommand(commandID int64) (*Command, error) {
	var resp Command
	path := fmt.Sprintf("/api/v1/agent_commands/%d/ack", commandID)
	if err := c.doRequest("PATCH", path, CommandAckRequest{}, &resp, true); err != nil {
		return nil, fmt.Errorf("ack command: %w", err)
	}
	return &resp, nil
}

func (c *Client) CompleteCommand(commandID int64, result map[string]any) (*Command, error) {
	req := CommandCompleteRequest{Result: result}
	var resp Command
	path := fmt.Sprintf("/api/v1/agent_commands/%d/complete", commandID)
	if err := c.doRequest("PATCH", path, req, &resp, true); err != nil {
		return nil, fmt.Errorf("complete command: %w", err)
	}
	return &resp, nil
}

func (c *Client) HandoffTask(ctx context.Context, taskID int64, targetAgentID int64, handoffContext string) (*TaskHandoff, error) {
	body := map[string]any{
		"to_agent_id": targetAgentID,
		"context":     handoffContext,
	}
	var resp TaskHandoff
	path := fmt.Sprintf("/api/v1/tasks/%d/handoff", taskID)
	if err := c.doRequestWithContext(ctx, "POST", path, body, &resp, true); err != nil {
		return nil, fmt.Errorf("handoff task: %w", err)
	}
	return &resp, nil
}

func (c *Client) GetPendingHandoffs(ctx context.Context) ([]TaskHandoff, error) {
	var resp []TaskHandoff
	if err := c.doRequestWithContext(ctx, "GET", "/api/v1/task_handoffs?status=pending", nil, &resp, true); err != nil {
		return nil, fmt.Errorf("get pending handoffs: %w", err)
	}
	return resp, nil
}

func (c *Client) AcceptHandoff(ctx context.Context, handoffID int64) (*TaskHandoff, error) {
	var resp TaskHandoff
	path := fmt.Sprintf("/api/v1/task_handoffs/%d/accept", handoffID)
	if err := c.doRequestWithContext(ctx, "PATCH", path, nil, &resp, true); err != nil {
		return nil, fmt.Errorf("accept handoff: %w", err)
	}
	return &resp, nil
}

func (c *Client) RejectHandoff(ctx context.Context, handoffID int64) (*TaskHandoff, error) {
	var resp TaskHandoff
	path := fmt.Sprintf("/api/v1/task_handoffs/%d/reject", handoffID)
	if err := c.doRequestWithContext(ctx, "PATCH", path, nil, &resp, true); err != nil {
		return nil, fmt.Errorf("reject handoff: %w", err)
	}
	return &resp, nil
}

type noContentError struct{}

func (e *noContentError) Error() string {
	return "no content"
}

func isNoContent(err error) bool {
	_, ok := err.(*noContentError)
	return ok
}

func (c *Client) doRequest(method, path string, body any, out any, requireAuth bool) error {
	return c.doRequestWithContext(context.Background(), method, path, body, out, requireAuth)
}

func (c *Client) doRequestWithContext(ctx context.Context, method, path string, body any, out any, requireAuth bool) error {
	var reqBody io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshaling request: %w", err)
		}
		reqBody = bytes.NewReader(data)
	}

	url := c.baseURL + path
	req, err := http.NewRequestWithContext(ctx, method, url, reqBody)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if requireAuth && c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNoContent {
		return &noContentError{}
	}

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("reading response: %w", err)
	}

	if resp.StatusCode >= 400 {
		var errResp ErrorResponse
		if json.Unmarshal(respBody, &errResp) == nil && errResp.Error != "" {
			return fmt.Errorf("api error (%d): %s", resp.StatusCode, errResp.Error)
		}
		return fmt.Errorf("api error (%d): %s", resp.StatusCode, string(respBody))
	}

	if out != nil && len(respBody) > 0 {
		if err := json.Unmarshal(respBody, out); err != nil {
			return fmt.Errorf("unmarshaling response: %w", err)
		}
	}

	return nil
}

type contextReader struct {
	ctx    context.Context
	reader io.Reader
}

func (r *contextReader) Read(p []byte) (int, error) {
	select {
	case <-r.ctx.Done():
		return 0, r.ctx.Err()
	default:
		return r.reader.Read(p)
	}
}

func sanitizeArtifactFilename(filename string) string {
	filename = strings.TrimSpace(filepath.Base(filename))
	if filename == "." || filename == string(filepath.Separator) {
		return ""
	}
	return filename
}
