class RenameTrelloCreatedAtToJoinedDate < ActiveRecord::Migration[7.0]
  def change
    rename_column :people, :trello_created_at, :joined_date
  end
end
