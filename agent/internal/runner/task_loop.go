package runner

import (
	"context"
	"sync/atomic"
	"time"

	"github.com/SweetSophia/apex-claw/agent/internal/apexclaw"
	"github.com/SweetSophia/apex-claw/agent/internal/logging"
)

type TaskRunner struct {
	client      *apexclaw.Client
	interval    time.Duration
	executor    Executor
	retryConfig RetryConfig
	active      atomic.Bool
	draining    atomic.Bool
}

func NewTaskRunner(client *apexclaw.Client, interval time.Duration, executor Executor) *TaskRunner {
	if interval == 0 {
		interval = 5 * time.Second
	}

	if client != nil {
		logging.InitLogger(client.AgentID())
	}

	return &TaskRunner{
		client:      client,
		interval:    interval,
		executor:    executor,
		retryConfig: DefaultRetryConfig(),
	}
}

func (t *TaskRunner) Active() bool {
	return t.active.Load()
}

func (t *TaskRunner) Draining() bool {
	return t.draining.Load()
}

func (t *TaskRunner) SetDraining(v bool) {
	t.draining.Store(v)
}

func (t *TaskRunner) Run(ctx context.Context) error {
	ticker := time.NewTicker(t.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			logging.Global().Info("task runner stopping", map[string]any{"error": ctx.Err().Error()})
			return ctx.Err()
		case <-ticker.C:
			if t.draining.Load() {
				continue
			}
			t.pollAndExecute(ctx)
		}
	}
}

func (t *TaskRunner) pollAndExecute(ctx context.Context) {
	task, err := t.client.GetNextTask()
	if err != nil {
		for attempt := 1; err != nil; attempt++ {
			backoff := t.retryConfig.BackoffDelay(attempt)
			logging.Global().Error("failed to get next task", map[string]any{"error": err.Error(), "backoff": backoff.String(), "attempt": attempt})
			select {
			case <-ctx.Done():
				return
			case <-time.After(backoff):
			}
			task, err = t.client.GetNextTask()
		}
	}

	if task == nil {
		return
	}

	logger := logging.Global()
	logger.Info("received task", map[string]any{"task_id": task.ID, "task_name": task.Name, "status": task.Status})

	if task.ClaimedByAgentID == nil {
		claimed, err := t.client.ClaimTask(task.ID)
		if err != nil {
			logger.Error("failed to claim task", map[string]any{"task_id": task.ID, "error": err.Error()})
			return
		}
		task = claimed
		logger.Info("claimed task", map[string]any{"task_id": task.ID})
	}

	t.active.Store(true)
	defer t.active.Store(false)

	result, attempts := t.executeWithRetry(ctx, task)
	if result.Error != nil {
		logger.Error("task failed after retries exhausted", map[string]any{"task_id": task.ID, "attempts": attempts, "error": result.Error.Error()})
		t.reportTaskFailure(task, attempts, result.Error)
		return
	}

	if result.Completed {
		_, err = t.client.CompleteTask(task.ID, result.Output)
		if err != nil {
			logger.Error("failed to complete task", map[string]any{"task_id": task.ID, "error": err.Error()})
			return
		}
		logger.Info("task completed", map[string]any{"task_id": task.ID, "attempts": attempts})
	}
}

func (t *TaskRunner) executeWithRetry(ctx context.Context, task *apexclaw.Task) (ExecutionResult, int) {
	logger := logging.Global()
	maxAttempts := t.retryConfig.MaxRetries + 1
	if maxAttempts < 1 {
		maxAttempts = 1
	}

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		result := t.executor.Execute(ctx, task)
		if result.Error == nil {
			if attempt > 1 {
				logger.Info("task execution succeeded after retry", map[string]any{"task_id": task.ID, "attempt": attempt})
			}
			return result, attempt
		}

		if attempt >= maxAttempts {
			return result, attempt
		}

		delay := t.retryConfig.BackoffDelay(attempt)
		logger.Warn("task execution failed, retrying", map[string]any{
			"task_id":        task.ID,
			"attempt":        attempt,
			"max_attempts":   maxAttempts,
			"retry_delay_ms": delay.Milliseconds(),
			"error":          result.Error.Error(),
		})
		t.markTaskRetrying(task, attempt, delay, result.Error)

		select {
		case <-ctx.Done():
			return ExecutionResult{Error: ctx.Err()}, attempt
		case <-time.After(delay):
		}
	}

	return ExecutionResult{}, maxAttempts
}

func (t *TaskRunner) markTaskRetrying(task *apexclaw.Task, attempt int, delay time.Duration, execErr error) {
	status := "retrying"
	note := execErr.Error()
	if delay > 0 {
		note = note + "; retrying in " + delay.String()
	}
	_, err := t.client.UpdateTask(task.ID, apexclaw.TaskUpdateRequest{
		Status:       &status,
		ActivityNote: &note,
	})
	if err != nil {
		logging.Global().Warn("failed to update task status to retrying", map[string]any{
			"task_id": task.ID,
			"attempt": attempt,
			"error":   err.Error(),
		})
	}
}

func (t *TaskRunner) reportTaskFailure(task *apexclaw.Task, attempts int, execErr error) {
	status := "failed"
	note := execErr.Error()
	_, err := t.client.UpdateTask(task.ID, apexclaw.TaskUpdateRequest{
		Status:       &status,
		ActivityNote: &note,
	})
	if err != nil {
		logging.Global().Warn("failed to report task failure", map[string]any{
			"task_id":  task.ID,
			"attempts": attempts,
			"error":    err.Error(),
		})
	}
}
