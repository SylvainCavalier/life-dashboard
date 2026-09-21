# Rack::Attack configuration for rate limiting and blocking

class Rack::Attack
  # Allow requests from localhost during development
  Rack::Attack.safelist('allow-localhost') do |req|
    Rails.env.development? && ['127.0.0.1', '::1'].include?(req.ip)
  end

  # Throttle login attempts by IP address
  # Compatible with Devise default routes
  Rack::Attack.throttle('login attempts by ip', limit: 5, period: 60.seconds) do |req|
    if (req.path == '/users/sign_in' || req.path.match(%r{^/users/sign_in})) && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email address
  # Handle both Devise and custom authentication forms
  Rack::Attack.throttle('login attempts by email', limit: 5, period: 60.seconds) do |req|
    if (req.path == '/users/sign_in' || req.path.match(%r{^/users/sign_in})) && req.post?
      # Try different possible parameter structures
      email = req.params.dig('user', 'email') || 
              req.params.dig('email') ||
              req.params.dig('session', 'email')
      email&.downcase if email
    end
  end

  # Throttle password reset attempts
  Rack::Attack.throttle('password reset attempts', limit: 3, period: 60.seconds) do |req|
    if (req.path == '/users/password' || req.path.match(%r{^/users/password})) && req.post?
      req.ip
    end
  end
  
  # Throttle registration attempts
  Rack::Attack.throttle('registration attempts', limit: 3, period: 60.seconds) do |req|
    if (req.path == '/users' || req.path == '/users/sign_up' || req.path.match(%r{^/users/sign_up})) && req.post?
      req.ip
    end
  end

  # Throttle API requests
  Rack::Attack.throttle('api requests', limit: 100, period: 60.seconds) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # General request throttling
  Rack::Attack.throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Coffre-fort : une session compromise ne doit pas pouvoir aspirer les entrees
  # une par une via /api/password_entries/:id/reveal.
  Rack::Attack.throttle('vault reveal', limit: 20, period: 5.minutes) do |req|
    req.ip if req.get? && req.path.match?(%r{^/api/password_entries/\d+/reveal$})
  end

  # Scanners de vulnerabilites : le dashboard n'a aucune de ces routes, toute
  # requete vers l'une d'elles est hostile. On coupe court pour garder des logs
  # lisibles et economiser les dynos.
  SCANNER_PATHS = %r{
    ^/(
      wp-(admin|login|content|includes) |
      wordpress | xmlrpc\.php | phpmyadmin | pma |
      \.env | \.git | \.aws | \.ssh |
      config\.json | credentials |
      vendor/phpunit | cgi-bin | solr | actuator | telescope |
      admin\.php | shell | eval-stdin\.php
    )
  }xi

  Rack::Attack.blocklist('scanners') do |req|
    SCANNER_PATHS.match?(req.path)
  end

  # Response when throttled
  self.throttled_responder = lambda do |_request|
    [429, {'Content-Type' => 'application/json'}, [{error: "Rate limit exceeded. Try again later."}.to_json]]
  end
end

# Enable Rack::Attack logging (only for throttles and blocks, not safelists)
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  match_type = payload[:match_type]
  next if match_type == :safelist

  Rails.logger.warn "[Rack::Attack] #{req.ip} #{req.request_method} #{req.fullpath} #{match_type}: #{payload[:match_discriminator]}"
end
