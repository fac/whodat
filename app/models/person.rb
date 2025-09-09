class Person < ApplicationRecord
  include Discard::Model

  has_one_attached :avatar

  scope :newbies, -> { where("joined_date > ?", 1.year.ago) }
end
