class AgentToken < ApplicationRecord
  TOKEN_BYTES = 32

  belongs_to :agent

  validates :token_digest, presence: true, uniqueness: true
  validate :single_active_token_per_agent

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  def self.issue!(agent:, name: nil, expires_at: nil)
    plaintext_token = SecureRandom.hex(TOKEN_BYTES)
    issued_at = Time.current

    agent_token = create!(
      agent: agent,
      name: name,
      token_digest: digest_token(plaintext_token),
      expires_at: expires_at,
      last_rotated_at: issued_at
    )

    [ agent_token, plaintext_token ]
  end

  def self.authenticate(plaintext_token)
    return nil if plaintext_token.blank?

    candidate_digest = digest_token(plaintext_token)
    agent_token = find_by(token_digest: candidate_digest)
    return nil unless agent_token
    return nil unless secure_digest_compare(agent_token.token_digest, candidate_digest)
    return nil if agent_token.revoked? || agent_token.expired?

    agent_token.touch(:last_used_at)
    agent_token
  end

  def self.digest_token(plaintext_token)
    OpenSSL::Digest::SHA256.hexdigest(plaintext_token.to_s)
  end

  def self.secure_digest_compare(stored_digest, candidate_digest)
    return false if stored_digest.blank? || candidate_digest.blank?
    return false unless stored_digest.bytesize == candidate_digest.bytesize

    ActiveSupport::SecurityUtils.secure_compare(stored_digest, candidate_digest)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def expires_soon?(within: 24.hours)
    expires_at.present? && expires_at <= Time.current + within
  end

  private

  def single_active_token_per_agent
    return unless agent
    return if revoked? || expired?

    existing_active_tokens = agent.agent_tokens.active.where.not(id: id)
    return unless existing_active_tokens.exists?

    errors.add(:base, "agent already has an active token")
  end
end
