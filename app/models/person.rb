class Person < ApplicationRecord
  include Discard::Model

  has_one_attached :avatar

  scope :everyone, -> { kept.with_attached_avatar.joins(:avatar_blob) }
  scope :newbies, -> { everyone.where("joined_date > ?", 1.year.ago) }
  scope :edinburgh, -> { everyone.where(location: "Edinburgh") }
  scope :remote, -> { everyone.where(location: "Remote") }

  def random(scope, seed, position)
    transaction do
      ActiveRecord::Base.connection.execute("SET SEED TO #{seed}")

      # Selects the user that is at a pseudo-random position
      # based on the seed
      scope.order('RANDOM()').offset(position).first
    end
  end
end
