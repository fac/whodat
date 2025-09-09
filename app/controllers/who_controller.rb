class WhoController < ApplicationController
  include Authorization

  def index
    @people = Person.kept.with_attached_avatar.count
    @newbies = Person.kept.where("trello_created_at > ?", 1.year.ago).count
  end

  def play
    scope = unless params[:recent].present?
        Person.kept.with_attached_avatar.all
      else
        Person.kept.where("trello_created_at > ?", 1.year.ago)
      end

    @person = scope.with_attached_avatar.select {|p| p.avatar.attached?}.sample

    names = @person.name.split(" ")
    @masked_name = names.map {|name| name.gsub(/\B[\w]/, "*") }.join(" ")
  end
end
