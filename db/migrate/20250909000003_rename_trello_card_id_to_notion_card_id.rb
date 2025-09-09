class RenameTrelloCardIdToNotionCardId < ActiveRecord::Migration[7.0]
  def change
    rename_column :people, :trello_card_id, :notion_card_id
  end
end
