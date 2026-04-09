module Api
  class TasksController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @tasks = Task.ordered
      render json: @tasks
    end

    def create
      @task = Task.new(task_params)
      if @task.save
        render json: @task, status: :created
      else
        render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @task = Task.find(params[:id])
      if @task.update(task_params)
        render json: @task
      else
        render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @task = Task.find(params[:id])
      @task.destroy
      head :no_content
    end

    private

    def task_params
      params.require(:task).permit(:description, :priority, :deadline, :completed)
    end
  end
end
