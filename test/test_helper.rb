ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include FactoryBot::Syntax::Methods
  end
end

# Les routes sont chargees paresseusement en test. `devise_for` etant ce qui
# enregistre les mappings Devise, un `sign_in` place avant la premiere requete
# echouerait avec "Could not find a valid mapping" -- de facon intermittente,
# selon l'ordre de la seed.
Rails.application.reload_routes_unless_loaded

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Toute l'application est privee : la plupart des tests ont besoin d'une
  # session ouverte.
  def sign_in_owner
    sign_in(create(:user))
  end
end
