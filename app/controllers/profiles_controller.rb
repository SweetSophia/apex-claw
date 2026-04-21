class ProfilesController < ApplicationController
  def show
    @user = current_user
    @api_token = current_user.api_token
    @registered_agents = current_user.agents.order(last_heartbeat_at: :desc, created_at: :desc)
  end

  def update
    @user = current_user

    if params[:user][:remove_avatar] == "1"
      @user.avatar.purge if @user.avatar.attached?
      @user.avatar_url = nil
    end

    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully."
    else
      @api_token = current_user.api_token
      @registered_agents = current_user.agents.order(last_heartbeat_at: :desc, created_at: :desc)
      render :show, status: :unprocessable_entity
    end
  end

  def regenerate_api_token
    current_user.api_tokens.destroy_all
    _api_token, plaintext_token = ApiToken.issue!(user: current_user, name: "default")
    flash[:api_token_plaintext] = plaintext_token
    redirect_to settings_path, notice: "API token regenerated. Copy it now — it won't be shown again."
  end

  def generate_join_token
    join_token, plaintext_token = JoinToken.issue!(user: current_user, created_by_user: current_user)
    flash[:join_token_plaintext] = plaintext_token
    flash[:join_token_expires_at] = join_token.expires_at.iso8601
    redirect_to settings_path(anchor: "agents"), notice: "Join token generated. Copy it now — it won't be shown again."
  end

  private

  def profile_params
    params.expect(user: [ :email_address, :avatar ])
  end
end
