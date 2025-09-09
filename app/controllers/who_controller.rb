class WhoController < ApplicationController
  include Authorization

  def index
    @everyone = Person.everyone.count
    @newbies = Person.newbies.count
    @edinburgh = Person.edinburgh.count
    @remote = Person.remote.count
    
    # Set a new random seed for this session
    session[:random_seed] = (rand * 2) - 1
    session[:position] = 0
  end

  def play
    scope = if params[:recent].present?
        Person.newbies
    elsif params[:edinburgh].present?
      Person.edinburgh
    elsif params[:remote].present?
      Person.remote
    else
      Person.everyone
    end

    # Get seed and position from session, with defaults
    seed = session[:random_seed] || (rand * 2) - 1
    position = session[:position] || 0
    
    # Get total count for this scope to handle wraparound
    total_count = scope.count
    
    # Reset position if we've gone through all records
    if position >= total_count
      session[:position] = 0
      position = 0
    end
    
    # Use the Person#random method to get the next person
    @person = Person.new.random(scope, seed, position)
    
    # Increment position for next call
    session[:position] = position + 1

    names = @person.name.split(" ")
    @masked_name = names.map {|name| name.gsub(/\B[\w]/, "*") }.join(" ")
  end
end
