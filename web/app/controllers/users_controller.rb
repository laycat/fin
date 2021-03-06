class UsersController < ApplicationController
  # FIXME before_filter :require_login?
  before_action :set_user, only: [:edit, :update, :destroy]
  skip_before_filter :require_login, only: [:new, :create]

  # FIXME prevent viewing users that aren't yours
  # FIXME prevent editing users that aren't yours
  # FIXME prevent deleting users that aren't yours

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  def create
    @user = User.new(user_params)

    if @user.save
      auto_login(@user)
      redirect_to root_url, notice: 'User was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /users/1
  def update
    if @user.update(user_params)
      redirect_to root_url, notice: 'User was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
    redirect_to root_url, notice: 'Your account was successfully deleted.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:username, :password, :password_confirmation)
    end
end
