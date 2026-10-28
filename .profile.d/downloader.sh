# Heroku source ce fichier au demarrage de chaque dyno (voir bin/downloader-binaries).
# Les binaires du Downloader vivent sur le disque ephemere du dyno, devant le PATH.
export DOWNLOADER_BIN_DIR="$HOME/tmp/downloader-bin"
export PATH="$DOWNLOADER_BIN_DIR:$PATH"

# Dyno web seulement, en arriere-plan : Puma demarre sans attendre (une vingtaine de
# secondes, pendant lesquelles la page Downloader affiche « module indisponible »).
# Dans un `heroku run`, lancer `bin/downloader-binaries` a la main si besoin.
case "${DYNO:-}" in
  web.*) ( "$HOME/bin/downloader-binaries" 2>&1 & ) ;;
esac
