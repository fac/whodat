NOTION_DATABASE_ID = "7ebee0d6-fb7b-4eea-9f76-87c4c7c26271"

namespace :notion do
  desc "Looks for Trello cards that have been archived (closed) and discards the person in the database"
  task clean: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.info "Cleaning database"

    client = Notion::Client.new
    database_id = ENV['NOTION_DATABASE_ID'] || NOTION_DATABASE_ID

    notion_cards = {}
    results = client.database_query(database_id: database_id, sorts: [{ property: "Name", direction: "ascending" }]) do |page|
      page.results.each do |result|
        card = NotionExtract.from(result)
        notion_cards[card.notion_id] = card
      end
    end

    Person.kept.find_each do |person|
      Rails.logger.info "Checking #{person.name}"

      card = notion_cards[person.trello_card_id]
      if card.nil?
        Rails.logger.info "Card not found. Deleting #{person.name}"
        person.discard!
      elsif card.archived?
        # This branch is probably exluded by the query above.
        Rails.logger.info "Card archived. Deleting #{person.name}"
        person.discard!
      end
    end
  end

  # This is the point that we start considering Notion updates as new changes
  # so as not to lose the old created_at dates from Trello
  desc "Loads (and updates) people from the Notion board"
  task load_people: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.info "Loading cards from Notion"

    client = Notion::Client.new
    database_id = ENV['NOTION_DATABASE_ID'] || NOTION_DATABASE_ID

    results = client.database_query(database_id: database_id, sorts: [{ property: "Name", direction: "ascending" }]) do |page|
      page.results.each do |result|
        begin
          card = NotionExtract.from(result)
          person = Person.find_or_initialize_by(trello_card_id: card.notion_id)

          Rails.logger.info "checking #{card.name}"

          # Don't skip if person doesn't exist
          # Skip if they exist and the updated time is after the card updated time. 
          if person.persisted? && person.updated_at > card.updated_at
            # if person.persisted? && person.updated_at > card.updated_at
            Rails.logger.info "No activity. Skipping"
            next
          end

          person.name = card.name
          person.title = card.title
          person.team = card.department
          person.trello_created_at = card.created_at
          person.save!

          if card.image_url.present?
            image_io = Down::NetHttp.open(card.image_url)
            person.avatar.attach(io: image_io, filename: card.image_filename)
          end

          Rails.logger.info "Person #{person.name}, #{person.title}, #{person.team} updated"
        rescue
          Rails.logger.info "Could not update"
        end
      end
    end
  end

  desc "Debug notion integration"
  task debug: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.info "Loading from Notion"

    client = Notion::Client.new
    database_id = ENV['NOTION_DATABASE_ID'] || NOTION_DATABASE_ID
    raise "Missing environment variable NOTION_DATABASE_ID" if database_id.nil?

    results = client.database_query(database_id: database_id, sorts: [{ property: "Name", direction: "ascending" }]) do |page|
      page.results.each do |result|
        line = NotionExtract.from(result).to_s
        puts line
      end
    end
  end


  # Walk the hierarchy of the block on the Who's Who page to extract properties
  class NotionExtract
    def self.from(node)
      new(node)
    end

    def initialize(node)
      @node = node
    end

    def notion_id
      @node.id
    rescue
      ""
    end

    def archived?
      @node.archived
    end

    def name_node_text
      @node[:properties][:Name][:title][0][:text][:content]
    rescue
      ""
    end

    def title_node_text
      @node[:properties][:"Job Title"][:rich_text][0][:text][:content]
    rescue
      ""
    end

    def name
      name, _ = name_node_text.split("[")
      name.strip if name
    rescue
      ""
    end

    def title
      # If the title is in the Title property
      return title_node_text unless title_node_text.blank?

      # Or maybe it's in the name property e.g. John Smith [Software Engineer]
      _, title = name_node_text.split("[")
      return title.gsub("]", "").strip if title
      ""
    rescue
      ""
    end

    def team
      @node[:properties][:Team][:multi_select][0][:name]
    rescue
      ""
    end

    def department
      @node[:properties][:Department][:status][:name]
    rescue
      ""
    end

    def location
      @node[:properties][:Location][:select][:name]
    rescue
      ""
    end

    def created_at
      @node.created_time
    rescue
      ""
    end

    def updated_at
      @node.last_edited_time
    rescue
      ""
    end

    def image_url
      @node&.cover.url || @node[:properties][:Attachments][:files][0][:file][:url]
    rescue
      ""
    end

    def image_filename
      # Attachments have filenames: @node[:properties][:Attachments][:files][0][:name]
      # Cover files don't unfortunately:
      "#{name.downcase.gsub(/\W/, "_")[0..20]}-#{updated_at[0..9]}.jpg"
    rescue
      ""
    end

    def to_s
      "#{notion_id}, #{name}, #{title}, #{team}, #{department}, #{location}, #{image_url[-20..]}, #{image_filename}, #{created_at}, #{updated_at}"
    end
  end
end
