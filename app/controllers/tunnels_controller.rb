class TunnelsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tunnel, only: %i[show destroy]

  def index
    @tunnels = current_user.tunnels.order(created_at: :desc)
  end

  def show
  end

  def create
    @tunnel = current_user.tunnels.build(tunnel_params)
    if @tunnel.save
      flash[:notice] = "Tunnel yaratildi!"
      redirect_to root_path
    else
      flash[:alert] = @tunnel.errors.full_messages.join(", ")
      redirect_to root_path
    end
  end

  def destroy
    @tunnel.destroy
    flash[:notice] = "Tunnel o'chirildi."
    redirect_to root_path
  end

  private

  def set_tunnel
    @tunnel = current_user.tunnels.find(params[:id])
  end

  def tunnel_params
    params.permit(:name, :local_port, :subdomain)
  end
end
