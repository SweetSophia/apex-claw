package apexclaw

import "time"

type Agent struct {
	ID              int64          `json:"id"`
	UserID          int64          `json:"user_id"`
	Name            string         `json:"name"`
	Status          string         `json:"status"`
	Hostname        string         `json:"hostname"`
	HostUID         string         `json:"host_uid"`
	Platform        string         `json:"platform"`
	Version         string         `json:"version"`
	Tags            []string       `json:"tags"`
	Metadata        map[string]any `json:"metadata"`
	LastHeartbeatAt *time.Time     `json:"last_heartbeat_at"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
}

type Task struct {
	ID               int64      `json:"id"`
	Name             string     `json:"name"`
	Description      string     `json:"description"`
	Output           string     `json:"output"`
	Priority         string     `json:"priority"`
	Status           string     `json:"status"`
	Blocked          bool       `json:"blocked"`
	Tags             []string   `json:"tags"`
	Completed        bool       `json:"completed"`
	CompletedAt      *time.Time `json:"completed_at"`
	DueDate          *time.Time `json:"due_date"`
	Position         int        `json:"position"`
	AssignedToAgent  bool       `json:"assigned_to_agent"`
	AssignedAt       *time.Time `json:"assigned_at"`
	AssignedAgentID  *int64     `json:"assigned_agent_id"`
	AgentClaimedAt   *time.Time `json:"agent_claimed_at"`
	ClaimedByAgentID *int64     `json:"claimed_by_agent_id"`
	BoardID          int64      `json:"board_id"`
	URL              string     `json:"url"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

type Command struct {
	ID                int64          `json:"id"`
	AgentID           int64          `json:"agent_id"`
	Kind              string         `json:"kind"`
	Payload           map[string]any `json:"payload"`
	State             string         `json:"state"`
	Result            map[string]any `json:"result"`
	RequestedByUserID int64          `json:"requested_by_user_id"`
	AckedAt           *time.Time     `json:"acked_at"`
	CompletedAt       *time.Time     `json:"completed_at"`
	CreatedAt         time.Time      `json:"created_at"`
	UpdatedAt         time.Time      `json:"updated_at"`
}

type TaskArtifact struct {
	ID          int64          `json:"id"`
	Filename    string         `json:"filename"`
	ContentType string         `json:"content_type"`
	Size        int64          `json:"size"`
	Metadata    map[string]any `json:"metadata"`
	CreatedAt   time.Time      `json:"created_at"`
}

type RegisterRequest struct {
	JoinToken string    `json:"join_token"`
	Agent     AgentInfo `json:"agent"`
}

type AgentInfo struct {
	Name     string            `json:"name"`
	Hostname string            `json:"hostname"`
	HostUID  string            `json:"host_uid"`
	Platform string            `json:"platform"`
	Version  string            `json:"version"`
	Tags     []string          `json:"tags"`
	Metadata map[string]string `json:"metadata"`
}

type RegisterResponse struct {
	Agent      Agent  `json:"agent"`
	AgentToken string `json:"agent_token"`
}

type HeartbeatRequest struct {
	Status   string         `json:"status"`
	Version  string         `json:"version,omitempty"`
	Platform string         `json:"platform,omitempty"`
	Metadata map[string]any `json:"metadata,omitempty"`
}

type HeartbeatResponse struct {
	Agent                    Agent        `json:"agent"`
	DesiredState             DesiredState `json:"desired_state"`
	TokenRotationRequired    bool         `json:"token_rotation_required"`
	HeartbeatIntervalSeconds int          `json:"heartbeat_interval_seconds"`
}

type RotateTokenResponse struct {
	Agent      Agent  `json:"agent"`
	AgentToken string `json:"agent_token"`
}

type DesiredState struct {
	Action string `json:"action"`
}

type TaskUpdateRequest struct {
	Status       *string `json:"status,omitempty"`
	Description  *string `json:"description,omitempty"`
	Priority     *string `json:"priority,omitempty"`
	Blocked      *bool   `json:"blocked,omitempty"`
	ActivityNote *string `json:"activity_note,omitempty"`
}

type CommandAckRequest struct{}

type CommandCompleteRequest struct {
	Result map[string]any `json:"result"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type TaskHandoff struct {
	ID          int64      `json:"id"`
	TaskID      int64      `json:"task_id"`
	FromAgentID int64      `json:"from_agent_id"`
	ToAgentID   int64      `json:"to_agent_id"`
	Context     string     `json:"context"`
	Status      string     `json:"status"`
	RespondedAt *time.Time `json:"responded_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}
