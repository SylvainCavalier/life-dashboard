# Pose X-Robots-Tag sur toutes les reponses de l'application, sans exception :
# pages du SPA, redirections de Warden, erreurs 404/500, telechargements,
# flux ICS, PDF. Les moteurs de recherche majeurs (Google, Bing, DuckDuckGo,
# Yandex) respectent cet en-tete, y compris sur les reponses non-HTML ou une
# balise <meta name="robots"> serait impossible.
class RobotsTagMiddleware
  VALUE = "noindex, nofollow, noarchive, nosnippet, noimageindex, notranslate".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers["X-Robots-Tag"] = VALUE
    [status, headers, body]
  end
end
