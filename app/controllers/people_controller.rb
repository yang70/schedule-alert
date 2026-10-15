class PeopleController < ApplicationController
  before_action :authenticate_user!
  rate_limit to: 30, within: 1.hour, name: "people_changes", only: :create, by: -> { current_user.id }
  rescue_from ActiveRecord::RecordNotUnique do
    render json: { errors: [ "Name has already been used in your account." ] }, status: :unprocessable_entity
  end

  def index
    @people = current_user.people.order(:name)
    render json: @people.as_json(only: %i[id name color])
  end

  def create
    @person = current_user.people.build(person_params)

    if @person.save
      render json: @person.as_json(only: %i[id name color]), status: :created
    else
      render json: { errors: @person.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def person_params
    params.require(:person).permit(:name, :color)
  end
end
