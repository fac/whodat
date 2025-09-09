class WhoController < ApplicationController
  include Authorization

  def index
    @everyone = Person.everyone.count
    @newbies = Person.newbies.count
    @edinburgh = Person.edinburgh.count
    @remote = Person.remote.count
    
    # Set a new random seed for this session
    session[:random_seed] = random_seed
    session[:position] = 0
  end

  def play
    scope = case params
    in {:recent}
      Person.newbies
    in {:edinburgh}
      Person.edinburgh
    in {:remote}
      Person.remote
    else
      Person.everyone
    end

    # Get seed and position from session, with defaults
    seed = session[:random_seed] || random_seed
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

  private

  def random_seed
    # A value between 1.0 and -1.0, inclusive, that is used
    # to provide the seed for the next call to the random function.
    # Postgres specific
    (rand * 2) - 1
  end
end
