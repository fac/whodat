class AddLocationToPerson < ActiveRecord::Migration[7.0]
  def change
    add_column :people, :location, :string
  end
end
