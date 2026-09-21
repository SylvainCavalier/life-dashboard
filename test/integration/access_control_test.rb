require "test_helper"

# Verrouillage de l'application. Ces tests sont la pour qu'un futur controleur
# ajoute par distraction sans authentification fasse echouer la suite.
class AccessControlTest < ActionDispatch::IntegrationTest
  # --- Sans session ---

  test "la racine redirige vers la page de connexion" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "une route SPA quelconque redirige vers la page de connexion" do
    get "/contacts"
    assert_redirected_to new_user_session_path
  end

  test "les endpoints API repondent 401 sans rediriger" do
    %w[
      /api/password_entries
      /api/personal_profile
      /api/health_profile
      /api/mail_accounts
      /api/contacts
      /api/documents
      /api/budget_entries
      /api/trips
      /api/projects
      /api/tasks
    ].each do |path|
      get path, headers: { "Accept" => "application/json" }
      assert_response :unauthorized, "#{path} devrait repondre 401"
    end
  end

  test "les ecritures API sont refusees sans session" do
    assert_no_difference "Contact.count" do
      post "/api/contacts",
        params: { contact: { first_name: "Intrus", last_name: "Test" } }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :unauthorized
  end

  test "la generation IA d'un voyage est refusee sans session" do
    trip = create(:trip)
    assert_no_enqueued_jobs do
      post "/api/trips/#{trip.id}/plan", headers: { "Accept" => "application/json" }
    end
    assert_response :unauthorized
  end

  test "le direct upload Active Storage est refuse sans session" do
    post rails_direct_uploads_path,
      params: { blob: { filename: "x.txt", byte_size: 1, checksum: "x", content_type: "text/plain" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "le flux ICS est refuse sans session ni token" do
    get "/api/calendar.ics"
    assert_response :unauthorized
  end

  test "le flux ICS est accessible avec le bon token" do
    with_env("CALENDAR_FEED_TOKEN" => "jeton-de-test") do
      get "/api/calendar.ics", params: { token: "jeton-de-test" }
      assert_response :success
      assert_match "BEGIN:VCALENDAR", response.body
    end
  end

  test "le flux ICS refuse un mauvais token" do
    with_env("CALENDAR_FEED_TOKEN" => "jeton-de-test") do
      get "/api/calendar.ics", params: { token: "mauvais" }
      assert_response :unauthorized
    end
  end

  test "il n'existe ni inscription ni reinitialisation de mot de passe" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:new_user_registration_path), "aucune route d'inscription ne doit exister"
    assert_not helpers.respond_to?(:new_user_password_path), "aucune route de mot de passe oublie ne doit exister"

    # Le catch-all du SPA absorbe ces chemins : ils n'atteignent jamais Devise
    # et se comportent comme n'importe quelle page privee.
    get "/users/sign_up"
    assert_redirected_to new_user_session_path

    # Et surtout : impossible de creer un compte par la porte de derriere.
    assert_no_difference "User.count" do
      post "/users", params: { user: { email: "intrus@example.test", password: "un-mot-de-passe-tres-long" } }
    end
  end

  # --- Avec session ---

  test "une session ouverte donne acces au dashboard et a l'API" do
    sign_in_owner

    get root_path
    assert_response :success

    get "/api/contacts", headers: { "Accept" => "application/json" }
    assert_response :success
  end

  # --- Coffre-fort ---

  test "la liste du coffre-fort ne contient aucun mot de passe" do
    PasswordEntry.create!(name: "Banque", login: "sylvain", password: "s3cr3t-tres-long")
    sign_in_owner

    get "/api/password_entries", headers: { "Accept" => "application/json" }
    assert_response :success

    body = response.parsed_body
    assert_equal 1, body.size
    assert_equal "Banque", body.first["name"]
    assert_not body.first.key?("password"), "l'index ne doit jamais exposer le mot de passe"
    assert_no_match "s3cr3t-tres-long", response.body
  end

  test "reveal renvoie un seul mot de passe, et seulement avec une session" do
    entry = PasswordEntry.create!(name: "Banque", login: "sylvain", password: "s3cr3t-tres-long")

    get reveal_api_password_entry_path(entry), headers: { "Accept" => "application/json" }
    assert_response :unauthorized

    sign_in_owner
    get reveal_api_password_entry_path(entry), headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal "s3cr3t-tres-long", response.parsed_body["password"]
  end

  # --- Anti-indexation ---

  test "chaque reponse porte l'en-tete X-Robots-Tag" do
    get root_path
    assert_match "noindex", response.headers["X-Robots-Tag"]

    sign_in_owner
    get root_path
    assert_match "noindex", response.headers["X-Robots-Tag"]
  end

  test "la politique de referrer ne casse pas la verification d'origine du CSRF" do
    get new_user_session_path
    policy = response.headers["Referrer-Policy"]

    # 'no-referrer' aurait ete plus etanche, mais le navigateur envoie alors
    # `Origin: null` y compris sur les formulaires same-origin : Rails rejette
    # la connexion avec InvalidAuthenticityToken. 'same-origin' ne transmet
    # rien aux destinations externes tout en preservant l'en-tete Origin.
    assert_equal "same-origin", policy
    assert_not_equal "no-referrer", policy
  end

  test "aucune violation CSP n'est renvoyee vers une route inexistante" do
    get new_user_session_path
    csp = response.headers["Content-Security-Policy"].to_s

    # Un report-uri sans route en face transforme chaque violation en
    # RoutingError bruyante dans les logs.
    assert_no_match(/report-uri/i, csp)
  end

  test "robots.txt interdit tout le site" do
    robots = Rails.root.join("public/robots.txt").read
    assert_match(/^User-agent: \*$/, robots)
    assert_match(/^Disallow: \/$/, robots)
  end

  private

  def with_env(vars)
    previous = vars.transform_values { |_| nil }
    vars.each_key { |k| previous[k] = ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| ENV[k] = v }
  end
end
