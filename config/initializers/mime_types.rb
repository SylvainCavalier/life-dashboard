# Rack ne connait pas l'extension du manifest de la webapp (public/manifest.webmanifest) :
# sans cette ligne, le fichier statique partirait en application/octet-stream.
Rack::Mime::MIME_TYPES[".webmanifest"] = "application/manifest+json"
