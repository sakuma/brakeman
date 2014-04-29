class UsersController < ApplicationController
  def test_sql_sanitize
    User.where("age > #{sanitize params[:age]}")
  end

  def test_before_action
    render @page
  end

  before_action :set_page

  def set_page
    @page = params[:page]
  end
end
