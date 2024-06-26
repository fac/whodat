namespace :trello do

  desc "Looks for Trello cards that have been archived (closed) and discards the person in the database"
  task clean: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.info "Cleaning database"

    Person.kept.find_each do |person|
      Rails.logger.info "Checking #{person.name}"

      begin
        card = Trello::Card.find(person.trello_card_id)
        if card.closed
          Rails.logger.info "Card closed. Deleting #{person.name}"
          person.discard!
        end
      rescue Trello::Error => e
        if e.status_code == 404
          Rails.logger.info "Card not found. Deleting #{person.name}"
          person.discard!
        else
          Rails.logger.warn "Unknown error. Status code: #{e.status_code}"
        end
      end
    end
  end

  desc "Loads (and updates) people from the Trello board"
  task load_people: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.info "Loading cards from Trello"

    board = ENV['TRELLO_BOARD_ID']
    raise "Missing environment variable TRELLO_BOARD_ID" if board.nil?

    lists = Trello::Board.find(board).lists
    lists.each do |list|
      Rails.logger.info "Checking #{list.name}"

      cards = Trello::List.find(list.id).cards
      cards.each do |c|
        card = Trello::Card.find(c.id)
        person = Person.find_or_initialize_by(trello_card_id: card.id)

        Rails.logger.info "checking #{card.name}"

        if person.persisted? && person.updated_at > card.last_activity_date
          Rails.logger.info "No activity. Skipping"
          next
        end

        name, title = CardName.name_and_title(card.name)
        person.name = name
        person.title = title
        person.team = list.name
        person.trello_created_at = card.created_at
        person.save!

        if card.cover_image && !card.cover_image.is_a?(Array)
          auth_header = "OAuth oauth_consumer_key=\"#{Rails.application.credentials.trello[:api_key]}\", oauth_token=\"#{Rails.application.credentials.
trello[:token]}\""
          image_io = Down::NetHttp.open(card.cover_image.url, headers: { "Authorization": auth_header })

          person.avatar.attach(io: image_io, filename: card.cover_image.file_name)
        end

        Rails.logger.info "Person #{person.name}, #{person.title}, #{person.team} updated"
      end
    end
  end
end
