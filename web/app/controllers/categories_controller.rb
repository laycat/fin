class CategoriesController < ApplicationController
  before_filter :require_login
  before_action :set_category, only: [:edit, :update, :destroy]

  # FIXME prevent viewing categories that aren't yours
  # FIXME prevent editing categories that aren't yours
  # FIXME prevent deleting categories that aren't yours

  # GET /categories
  def index
    @categories = current_user.categories.all
  end

  # GET /categories/new
  def new
    @category = Category.new
  end

  # GET /categories/1/edit
  def edit
  end

  # POST /categories
  def create
    @category = Category.new(category_params)
    @category.user = current_user

    if @category.save
      redirect_to categories_path, notice: 'Category was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /categories/1
  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: 'Category was successfully updated.'
    else
      render action: 'edit'
    end
  end

  # DELETE /categories/1
  def destroy
    @category.destroy
    redirect_to categories_path
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category
      @category = Category.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def category_params
      params.require(:category).permit(:name)
    end
end
