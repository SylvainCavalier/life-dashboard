require_relative "boot"

require "rails/all"
require_relative "../lib/middleware/robots_tag_middleware"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LifeDashboard
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks middleware))
    
    # Rack::Attack s'insere lui-meme via son railtie : le declarer ici en plus
    # le montait deux fois, chaque requete etait donc comptee double et tous les
    # seuils de config/initializers/rack_attack.rb valaient la moitie de leur
    # valeur affichee.

    # Dashboard strictement prive : aucun contenu ne doit etre indexe.
    # L'en-tete est pose par un middleware, et non par
    # action_dispatch.default_headers, car ces derniers ne s'appliquent qu'aux
    # reponses passant par ActionController. La redirection vers la page de
    # connexion, elle, est produite par Warden en Rack pur -- or c'est
    # precisement la reponse qu'un crawler recoit. En position 0, le middleware
    # est le plus exterieur de la pile : aucune reponse ne lui echappe, pas meme
    # le 403 de l'autorisation d'hote ni les fichiers statiques.
    config.middleware.insert_before 0, RobotsTagMiddleware

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Heure de Paris : les heures saisies dans l'agenda ("2026-09-22T09:00", sans
    # fuseau) sont interpretees et renvoyees en heure francaise, et les journees
    # entieres (Google Calendar) commencent a minuit heure de Paris.
    config.time_zone = "Europe/Paris"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
