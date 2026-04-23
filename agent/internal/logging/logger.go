package logging

import (
	"encoding/json"
	"io"
	stdlog "log"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/envcompat"
)

type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
)

var levelNames = map[Level]string{
	LevelDebug: "DEBUG",
	LevelInfo:  "INFO",
	LevelWarn:  "WARN",
	LevelError: "ERROR",
}

type Logger struct {
	mu      sync.Mutex
	logger  *stdlog.Logger
	level   Level
	agentID int64
}

type entry struct {
	Timestamp string `json:"ts"`
	Level     string `json:"level"`
	AgentID   int64  `json:"agent_id"`
	Message   string `json:"msg"`
}

var (
	globalMu     sync.RWMutex
	globalLogger = NewLogger(os.Stderr, parseLevel(envcompat.FirstEnv(os.Getenv, "APEX_CLAW_LOG_LEVEL", "CLAWDECK_LOG_LEVEL")), 0)
)

func NewLogger(w io.Writer, level Level, agentID int64) *Logger {
	if w == nil {
		w = os.Stderr
	}
	return &Logger{
		logger:  stdlog.New(w, "", 0),
		level:   level,
		agentID: agentID,
	}
}

func InitLogger(agentID int64) {
	globalMu.Lock()
	defer globalMu.Unlock()
	globalLogger = NewLogger(os.Stderr, parseLevel(envcompat.FirstEnv(os.Getenv, "APEX_CLAW_LOG_LEVEL", "CLAWDECK_LOG_LEVEL")), agentID)
}

func Global() *Logger {
	globalMu.RLock()
	defer globalMu.RUnlock()
	return globalLogger
}

func (l *Logger) Debug(msg string, fields map[string]any) { l.log(LevelDebug, msg, fields) }
func (l *Logger) Info(msg string, fields map[string]any)  { l.log(LevelInfo, msg, fields) }
func (l *Logger) Warn(msg string, fields map[string]any)  { l.log(LevelWarn, msg, fields) }
func (l *Logger) Error(msg string, fields map[string]any) { l.log(LevelError, msg, fields) }

func (l *Logger) log(level Level, msg string, fields map[string]any) {
	if l == nil || level < l.level {
		return
	}

	record := make(map[string]any, len(fields)+4)
	record["ts"] = time.Now().UTC().Format(time.RFC3339)
	record["level"] = levelNames[level]
	record["agent_id"] = l.agentID
	record["msg"] = msg
	for k, v := range fields {
		record[k] = v
	}

	payload, err := json.Marshal(record)
	if err != nil {
		fallback, _ := json.Marshal(map[string]any{
			"ts":       time.Now().UTC().Format(time.RFC3339),
			"level":    levelNames[LevelError],
			"agent_id": l.agentID,
			"msg":      "failed to marshal log entry",
			"error":    err.Error(),
		})
		l.mu.Lock()
		l.logger.Print(string(fallback))
		l.mu.Unlock()
		return
	}

	l.mu.Lock()
	l.logger.Print(string(payload))
	l.mu.Unlock()
}

func parseLevel(value string) Level {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "DEBUG":
		return LevelDebug
	case "WARN", "WARNING":
		return LevelWarn
	case "ERROR":
		return LevelError
	case "INFO", "":
		fallthrough
	default:
		return LevelInfo
	}
}
