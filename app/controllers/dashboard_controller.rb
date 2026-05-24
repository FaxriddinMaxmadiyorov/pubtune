class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @tunnels = current_user.tunnels.order(created_at: :desc)
    @active_count = @tunnels.where(status: "active").count
    @total_count  = @tunnels.count
  end
end
