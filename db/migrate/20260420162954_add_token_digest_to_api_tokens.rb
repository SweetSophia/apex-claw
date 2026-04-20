class AddTokenDigestToApiTokens < ActiveRecord::Migration[8.0]
  def up
    add_column :api_tokens, :token_digest, :string, null: true

    # Backfill using raw SQL to avoid dependency on model class methods
    # that may change in future versions. Each token column holds the
    # plaintext; we hash it with SHA-256 for the digest.
    execute <<-SQL
      UPDATE api_tokens SET token_digest = encode(digest(token, 'sha256'), 'hex')
    SQL

    change_column_null :api_tokens, :token_digest, false
    remove_column :api_tokens, :token
  end

  def down
    add_column :api_tokens, :token, :string, null: true

    # NOTE: Original plaintext tokens are lost after the `up` migration.
    # Rollback generates new random tokens — all existing API integrations
    # will need to be re-issued.
    execute <<-SQL
      UPDATE api_tokens SET token = encode(gen_random_bytes(32), 'hex')
    SQL

    change_column_null :api_tokens, :token, false
    remove_column :api_tokens, :token_digest
  end
end
