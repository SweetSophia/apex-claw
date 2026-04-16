require "test_helper"

class AgentTokenTest < ActiveSupport::TestCase
  test "issue persists digest and returns plaintext token once" do
    agent = Agent.create!(user: users(:one), name: "Builder")

    agent_token, plaintext_token = AgentToken.issue!(agent: agent, name: "Primary")

    assert plaintext_token.present?
    assert_equal agent, agent_token.agent
    assert agent_token.token_digest.present?
    assert_not_equal plaintext_token, agent_token.token_digest
    assert_equal AgentToken.digest_token(plaintext_token), agent_token.token_digest
    assert agent_token.last_rotated_at.present?
  end

  test "authenticate returns token and updates last_used_at for valid plaintext token" do
    agent = Agent.create!(user: users(:one), name: "Runner")
    agent_token, plaintext_token = AgentToken.issue!(agent: agent)

    assert_nil agent_token.last_used_at

    authenticated_token = AgentToken.authenticate(plaintext_token)

    assert_equal agent_token, authenticated_token
    assert authenticated_token.last_used_at.present?
  end

  test "active scope includes only non revoked non expired tokens" do
    agent = Agent.create!(user: users(:one), name: "Scoped")
    active_token, = AgentToken.issue!(agent: agent, expires_at: 2.days.from_now)
    expired_token = AgentToken.create!(
      agent: agent,
      name: "Expired",
      token_digest: AgentToken.digest_token("expired"),
      expires_at: 1.minute.ago,
      revoked_at: Time.current,
      last_rotated_at: Time.current
    )

    assert_includes AgentToken.active, active_token
    assert_not_includes AgentToken.active, expired_token
  end

  test "expired? revoked? and expires_soon? reflect token state" do
    agent = Agent.create!(user: users(:one), name: "Flags")

    expiring_token, = AgentToken.issue!(agent: agent, expires_at: 2.hours.from_now)
    assert_not expiring_token.expired?
    assert_not expiring_token.revoked?
    assert expiring_token.expires_soon?(within: 3.hours)
    assert_not expiring_token.expires_soon?(within: 1.hour)

    expiring_token.update!(revoked_at: Time.current)
    assert expiring_token.revoked?

    expired_token = AgentToken.create!(
      agent: agent,
      name: "Expired",
      token_digest: AgentToken.digest_token("expired-2"),
      expires_at: 1.minute.ago,
      revoked_at: Time.current,
      last_rotated_at: Time.current
    )
    assert expired_token.expired?
  end

  test "authenticate rejects revoked token" do
    agent = Agent.create!(user: users(:one), name: "Revoked")
    agent_token, plaintext_token = AgentToken.issue!(agent: agent)
    agent_token.update!(revoked_at: Time.current)

    assert_nil AgentToken.authenticate(plaintext_token)
  end

  test "authenticate rejects expired token" do
    agent = Agent.create!(user: users(:one), name: "Expired")
    agent_token, plaintext_token = AgentToken.issue!(agent: agent, expires_at: 1.minute.from_now)
    agent_token.update!(expires_at: 1.minute.ago)

    assert_nil AgentToken.authenticate(plaintext_token)
  end

  test "only one active token is allowed per agent" do
    agent = Agent.create!(user: users(:one), name: "Single Active")
    AgentToken.issue!(agent: agent)

    duplicate = AgentToken.new(
      agent: agent,
      name: "Duplicate",
      token_digest: AgentToken.digest_token("duplicate"),
      last_rotated_at: Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages, "agent already has an active token"
  end

  test "does not store plaintext token column" do
    assert_not_includes AgentToken.column_names, "token"
  end
end
