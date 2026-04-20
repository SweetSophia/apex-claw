class ApiToken < ApplicationRecord
  TOKEN_BYTES = 32

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :name, presence: true

  before_validation :generate_token, on: :create

  def self.authenticate(plaintext_token)
    return nil if plaintext_token.blank?

    candidate_digest = digest_token(plaintext_token)
    api_token = find_by(token_digest: candidate_digest)
    return nil unless api_token
    return nil unless secure_digest_compare(api_token.token_digest, candidate_digest)

    api_token.touch(:last_used_at)
    api_token.user
  end

  def self.digest_token(plaintext_token)
    OpenSSL::Digest::SHA256.hexdigest(plaintext_token.to_s)
  end

  def self.secure_digest_compare(stored_digest, candidate_digest)
    return false if stored_digest.blank? || candidate_digest.blank?
    return false unless stored_digest.bytesize == candidate_digest.bytesize
    ActiveSupport::SecurityUtils.secure_compare(stored_digest, candidate_digest)
  end

  def self.issue!(user:, name: nil)
    api_token = new(user: user, name: name)
    api_token.save!
    [ api_token, api_token.instance_variable_get(:@plaintext_token) ]
  end

  private

  def generate_token
    plaintext = SecureRandom.hex(TOKEN_BYTES)
    self.token_digest = self.class.digest_token(plaintext)
    @plaintext_token = plaintext
  end
end
