# Grover pilote un Chrome headless via Puppeteer pour l'export PDF du CV.
#
# En local, Puppeteer utilise le Chromium qu'il a telecharge dans node_modules.
# Sur Heroku, il n'y a pas de navigateur dans le slug : le buildpack
# heroku/google-chrome en installe un et expose son chemin dans
# GOOGLE_CHROME_BIN (voir DEPLOY.md).
Grover.configure do |config|
  config.options = {
    # Sur un dyno, Chrome tourne en root sans namespaces utilisateur : le bac a
    # sable ne peut pas s'initialiser. --disable-dev-shm-usage evite les crashs
    # lies au /dev/shm de 64 Mo des conteneurs.
    launch_args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--no-zygote",
      "--single-process"
    ],
    timeout: 30_000,
    wait_until: "domcontentloaded"
  }

  chrome_path = ENV["GOOGLE_CHROME_BIN"].presence || ENV["GOOGLE_CHROME_SHIM"].presence
  config.options[:executable_path] = chrome_path if chrome_path
end
