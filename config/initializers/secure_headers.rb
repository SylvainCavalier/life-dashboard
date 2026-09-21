# SecureHeaders configuration
# This gem provides security headers to protect against XSS, clickjacking, and other attacks

# Host du bucket OVH : necessaire en connect_src pour que le direct upload
# Active Storage (PUT XHR vers l'URL pre-signee) ne soit pas bloque par la CSP.
OVH_S3_CSP_ORIGIN = begin
  endpoint = ENV["OVH_S3_ENDPOINT"].presence
  endpoint ? URI.parse(endpoint).then { |uri| "#{uri.scheme}://#{uri.host}" } : nil
rescue URI::InvalidURIError
  nil
end

SecureHeaders::Configuration.default do |config|
  # Content Security Policy
  config.csp = {
    # Fetch directives specify the valid sources for various types of content
    default_src: %w('self'),
    base_uri: %w('self'),
    child_src: %w('self'),
    connect_src: %w('self' ws: wss:) + [ OVH_S3_CSP_ORIGIN ].compact,
    font_src: %w('self' https: data:),
    # Allow form submissions to self and external providers (for OAuth)
    form_action: %w('self'),
    frame_ancestors: %w('none'),
    frame_src: %w('self'),
    img_src: %w('self' https: data:),
    manifest_src: %w('self'),
    media_src: %w('self'),
    object_src: %w('none'),
    script_src: %w('self'),
    style_src: %w('self' 'unsafe-inline'),
    worker_src: %w('self'),
    
    # Development-specific rules for Vite
    upgrade_insecure_requests: Rails.env.production? # Only force HTTPS in production
    # Pas de report_uri : aucune route ne collectait ces rapports, chaque
    # violation generait donc une RoutingError et une trace complete dans les
    # logs. Les violations restent visibles dans la console du navigateur.
  }

  # Add Vite development server support
  if Rails.env.development?
    begin
      vite_host = ViteRuby.config.host_with_port
      config.csp[:connect_src] += ["http://#{vite_host}", "ws://#{vite_host}"]
      config.csp[:script_src] += ["http://#{vite_host}", "'unsafe-eval'"]
      config.csp[:style_src] += ["http://#{vite_host}"]
    rescue => e
      Rails.logger.warn "Could not configure Vite CSP: #{e.message}"
    end
  end

  # Test environment modifications
  if Rails.env.test?
    config.csp[:script_src] += %w('unsafe-inline' 'unsafe-eval')
    config.csp[:style_src] += %w('unsafe-inline')
  end

  # HTTP Strict Transport Security - only in production
  if Rails.env.production?
    config.hsts = "max-age=31536000; includeSubDomains; preload"
  end

  # X-Frame-Options
  config.x_frame_options = 'DENY'

  # X-Content-Type-Options
  config.x_content_type_options = 'nosniff'

  # X-XSS-Protection (legacy, but still useful for older browsers)
  config.x_xss_protection = '1; mode=block'

  # Referrer Policy
  # Dashboard prive sur un domaine volontairement non reference : on ne veut pas
  # que ce domaine fuite dans les logs des sites tiers via le Referer.
  #
  # 'same-origin' et non 'no-referrer' : avec no-referrer, le navigateur envoie
  # `Origin: null` y compris sur les formulaires same-origin, ce qui fait echouer
  # la verification d'origine du CSRF de Rails (InvalidAuthenticityToken a la
  # connexion). same-origin ne transmet rien aux destinations externes, ce qui
  # est le but recherche, tout en preservant l'en-tete Origin en interne.
  config.referrer_policy = 'same-origin'
end

# Configuration pour les pages d'erreur et de maintenance
SecureHeaders::Configuration.override(:error_pages) do |config|
  config.csp[:style_src] += ["'unsafe-inline'"]
  config.csp[:script_src] += ["'unsafe-inline'"]
end