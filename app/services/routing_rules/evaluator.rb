module RoutingRules
  class Evaluator
    # Evaluate routing rules for a task and auto-assign if a match is found
    def self.evaluate(task)
      new(task).evaluate_and_assign!
    end

    def initialize(task)
      @task = task
    end

    # Returns the matching RoutingRule or nil
    def evaluate_and_assign!
      @task.with_lock do
        return nil if @task.assigned_agent_id.present?

        matching_rule = find_best_match
        return nil unless matching_rule

        agent = matching_rule.agent
        return nil unless agent&.active_for_work?

        assign_task(agent)
        matching_rule
      end
    end

    private

    def find_best_match
      RoutingRule.active.where(user_id: @task.user_id).includes(:agent).by_priority.detect do |rule|
        next false unless rule.matches?(@task)

        rule.agent&.active_for_work?
      end
    end

    def assign_task(agent)
      @task.activity_source = "routing"
      @task.assign_to_agent!

      @task.activity_source = "routing"
      @task.update!(assigned_agent: agent)
    end
  end
end
