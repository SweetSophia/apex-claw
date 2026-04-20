class ApiToken < ApplicationRecord
  TOKEN_BYTES = 32

  # Exposes the plaintext token once after creation so callers can
  # display it to the user. Not persisted.
  attr_reader :plaintext_token

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :name, presence: true

  before_validation :generate_token, on: :create

  def self.authenticate(plaintext_token)
    return nil if plaintext_token.blank?

    candidate_digest = digest_token(plaintext_token)
    api_token = find_by(token_digest: candidate_digest)
    return nil unless api_token
    # DB lookup already confirmed digest match; the plaintext secret
    # is protected by the one-way hash. No timing-safe compare needed
    # on the hash itself since DB lookup isn't timing-safe either.

    api_token.touch(:last_used_at)
    api_token.user
  end

  def self.digest_token(plaintext_token)
    OpenSSL::Digest::SHA256.hexdigest(plaintext_token.to_s)
  end

  def self.issue!(user:, name: nil)
    api_token = new(user: user, name: name)
    api_token.save!
    [ api_token, api_token.plaintext_token ]
  end

  private

  def generate_token
    plaintext = SecureRandom.hex(TOKEN_BYTES)
    self.token_digest = self.class.digest_token(plaintext)
    @plaintext_token = plaintext
  end
end
