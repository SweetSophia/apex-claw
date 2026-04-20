class AddTokenDigestToApiTokens < ActiveRecord::Migration[8.0]
  def up
    add_column :api_tokens, :token_digest, :string, null: true
    # Backfill existing tokens
    ApiToken.find_each do |token|
      token.update!(token_digest: ApiToken.digest_token(token.token))
    end
    change_column_null :api_tokens, :token_digest, false
    remove_column :api_tokens, :token
  end

  def down
    add_column :api_tokens, :token, :string, null: true
    ApiToken.find_each do |token|
      token.update!(token: SecureRandom.hex(ApiToken::TOKEN_BYTES))
    end
    change_column_null :api_tokens, :token, false
    remove_column :api_tokens, :token_digest
  end
end
