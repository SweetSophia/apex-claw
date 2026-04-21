class SkillsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_skill, only: [:show, :update, :destroy]

  def index
    @skills = current_user.skills.order(updated_at: :desc)
  end

  def show
  end

  def create
    @skill = current_user.skills.build(skill_params)
    if @skill.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("skills_list", partial: "skills/skill_card", locals: { skill: @skill }) }
        format.html { redirect_to skills_path, notice: "Skill created" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("skill_form", partial: "skills/form", locals: { skill: @skill }), status: :unprocessable_entity }
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @skill.update(skill_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@skill), partial: "skills/skill_card", locals: { skill: @skill }) }
        format.html { redirect_to skill_path(@skill), notice: "Skill updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("skill_form", partial: "skills/form", locals: { skill: @skill }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @skill.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@skill)) }
      format.html { redirect_to skills_path, notice: "Skill deleted" }
    end
  end

  private

  def set_skill
    @skill = current_user.skills.find(params[:id])
  end

  def skill_params
    params.require(:skill).permit(:name, :description, :body, :shared)
  end
end