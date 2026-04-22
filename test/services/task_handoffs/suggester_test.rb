require "test_helper"

class TaskHandoffs::SuggesterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @board = boards(:one)
    @task = tasks(:one)
    @agent_sequence = 0

    @assigned_agent = create_agent("Assigned Agent")
    @claiming_agent = create_agent("Claiming Agent")
    @task.update!(assigned_agent: @assigned_agent, claimed_by_agent: @claiming_agent)

    @ruby = Skill.create!(user: @user, name: "Ruby")
    @rails = Skill.create!(user: @user, name: "Rails")
  end

  test "suggest ranks same-user available agents by skills and workload" do
    best_agent = create_agent("Best Agent", max_concurrent_tasks: 5)
    add_skills(best_agent, @ruby, @rails)

    partial_agent = create_agent("Partial Agent", max_concurrent_tasks: 5)
    add_skills(partial_agent, @ruby)

    capacity_agent = create_agent("Capacity Agent", max_concurrent_tasks: 2)
    add_skills(capacity_agent, @ruby, @rails)

    offline_agent = create_agent("Offline Agent", status: :offline)
    add_skills(offline_agent, @ruby, @rails)

    archived_agent = create_agent("Archived Agent")
    add_skills(archived_agent, @ruby, @rails)
    archived_agent.update!(archived_at: Time.current, archived_by: @user)

    other_user_agent = create_agent("Other Workspace Agent", user: @other_user)
    add_skills(
      other_user_agent,
      Skill.create!(user: @other_user, name: "Ruby"),
      Skill.create!(user: @other_user, name: "Rails")
    )

    create_task_for(best_agent, name: "Best active workload", status: :in_progress)
    create_task_for(best_agent, name: "Best completed workload", status: :done)
    create_task_for(capacity_agent, name: "Capacity task 1", status: :up_next)
    create_task_for(capacity_agent, name: "Capacity task 2", status: :in_progress)
    @task.update!(required_skills: ["Ruby", "Rails"])

    suggestions = TaskHandoffs::Suggester.new(@task).suggest(limit: 10)

    assert_equal [ best_agent, partial_agent, capacity_agent ],
                 suggestions.map { |entry| entry[:agent] }
    assert_equal [ "Skills match: 2/2", "Available", "Workload: 1/5 tasks" ], suggestions.first[:reasons]
    assert_equal [ "Skills match: 2/2", "Available", "Workload: 2/2 tasks (at capacity)" ],
                 suggestions.last[:reasons]

    suggested_agents = suggestions.map { |entry| entry[:agent] }
    refute_includes suggested_agents, @assigned_agent
    refute_includes suggested_agents, @claiming_agent
    refute_includes suggested_agents, offline_agent
    refute_includes suggested_agents, archived_agent
    refute_includes suggested_agents, other_user_agent
    assert suggestions.each_cons(2).all? { |left, right| left[:score] >= right[:score] }
  end

  test "suggest treats missing required skills as equal for all agents" do
    task = Task.create!(user: @other_user, board: boards(:two), name: "No Skill Task", required_skills: [])

    alpha = create_agent("Alpha Agent", user: @other_user)
    beta = create_agent("Beta Agent", user: @other_user)

    alpha_skill = Skill.create!(user: @other_user, name: "Go")
    add_skills(alpha, alpha_skill)

    suggestions = TaskHandoffs::Suggester.new(task).suggest(limit: 2)

    assert_equal [ alpha, beta ], suggestions.map { |entry| entry[:agent] }
    assert_equal suggestions.first[:score], suggestions.second[:score]
    assert_equal [ "Skills match: no requirements", "Available", "Workload: 0/5 tasks" ],
                 suggestions.first[:reasons]
    assert_equal [ "Skills match: no requirements", "Available", "Workload: 0/5 tasks" ],
                 suggestions.second[:reasons]
  end

  private

  def create_agent(name, user: @user, status: :online, max_concurrent_tasks: 5)
    @agent_sequence += 1

    Agent.create!(
      user: user,
      name: name,
      hostname: "agent-#{@agent_sequence}.local",
      host_uid: "agent-#{user.id}-#{@agent_sequence}",
      platform: "linux",
      status: status,
      max_concurrent_tasks: max_concurrent_tasks
    )
  end

  def add_skills(agent, *skills)
    skills.each do |skill|
      AgentSkill.create!(agent: agent, skill: skill)
    end
  end

  def create_task_for(agent, name:, status:)
    Task.create!(
      user: agent.user,
      board: agent.user == @user ? @board : boards(:two),
      name: name,
      status: status,
      assigned_agent: agent
    )
  end
end
