class BoardsController < ApplicationController
  before_action :set_board, only: [:show, :update, :destroy, :update_task_status]

  def index
    # Redirect to the first board
    @board = current_user.boards.first
    if @board
      redirect_to board_path(@board)
    else
      # Create a default board if none exists
      @board = current_user.boards.create!(name: "Personal", icon: "📋", color: "gray")
      redirect_to board_path(@board)
    end
  end

  def show
    @board_page = true
    session[:last_board_id] = @board.id
    @view_mode = params[:view] == "timeline" ? "timeline" : "board"
    @current_tag = params[:tag].presence
    @tasks = @board.tasks.includes(:user, :assigned_agent, :claimed_by_agent)

    # Filter by tag if specified
    if @current_tag.present?
      @tasks = @tasks.where("? = ANY(tasks.tags)", @current_tag)
    end

    # Group tasks by status
    @columns = {
      inbox: @tasks.inbox.order(position: :asc),
      up_next: @tasks.up_next.order(position: :asc),
      in_progress: @tasks.in_progress.order(position: :asc),
      in_review: @tasks.in_review.order(position: :asc),
      done: @tasks.done.order(position: :asc)
    }

    @timeline_tasks = @tasks
      .where.not(due_date: nil)
      .reorder(due_date: :asc, position: :asc)

    minimum_timeline_days = 14
    maximum_timeline_days = 90
    furthest_due_date = @timeline_tasks.maximum(:due_date)

    @timeline_start = @timeline_tasks.minimum(:due_date) || Date.current
    requested_timeline_end = [furthest_due_date || Date.current, @timeline_start + (minimum_timeline_days - 1).days].max
    @timeline_end = [requested_timeline_end, @timeline_start + (maximum_timeline_days - 1).days].min
    @timeline_days = (@timeline_start..@timeline_end).to_a
    @timeline_truncated = furthest_due_date.present? && furthest_due_date > @timeline_end

    # Get all unique tags for the sidebar filter
    @all_tags = @board.tasks.where.not(tags: []).pluck(:tags).flatten.uniq.sort

    # Get all boards for the sidebar
    @boards = current_user.boards

    # Get API token for agent status display
    @api_token = current_user.api_token

    @selected_task = @board.tasks.includes(:activities, :subtasks).find_by(id: params[:task_id]) if params[:task_id].present?

    if params[:new_task].present?
      @task = @board.tasks.new(user: current_user)
    end
  end

  def create
    @board = current_user.boards.new(board_params)

    if @board.save
      redirect_to board_path(@board), notice: "Board created."
    else
      redirect_to boards_path, alert: @board.errors.full_messages.join(", ")
    end
  end

  def update
    if @board.update(board_params)
      redirect_to board_path(@board), notice: "Board updated."
    else
      redirect_to board_path(@board), alert: @board.errors.full_messages.join(", ")
    end
  end

  def destroy
    # Don't allow deleting the last board
    if current_user.boards.count <= 1
      redirect_to board_path(@board), alert: "Cannot delete your only board."
      return
    end

    @board.destroy
    redirect_to boards_path, notice: "Board deleted."
  end

  def update_task_status
    # Update positions for all tasks in the column
    if params[:task_ids].present?
      params[:task_ids].each_with_index do |task_id, index|
        task = @board.tasks.find(task_id)
        task.update_columns(position: index + 1)
      end
    end

    # If a specific task changed status (moved between columns)
    if params[:task_id].present? && params[:status].present?
      @task = @board.tasks.find(params[:task_id])
      @task.activity_source = "web"
      @task.update!(status: params[:status])
    end

    head :ok
  end

  private

  def set_board
    @board = current_user.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :icon, :color)
  end
end
