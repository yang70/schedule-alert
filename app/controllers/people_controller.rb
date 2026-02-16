class PeopleController < ApplicationController
  before_action :authenticate_user!

  def index
    @people = current_user.people.order(:name)
    render json: @people
  end

  def create
    @person = current_user.people.build(person_params)
    
    if @person.save
      render json: @person, status: :created
    else
      render json: { errors: @person.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def person_params
    params.require(:person).permit(:name, :color)
  end
end
