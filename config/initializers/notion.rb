require 'notion'

Notion.configure do |config|
  config.token = Rails.application.credentials.notion[:internal_integration_secret]
end
