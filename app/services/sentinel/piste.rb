# Espace de noms des API PISTE (piste.gouv.fr). Les erreurs vivent ici et non
# dans client.rb : Zeitwerk ne saurait pas les trouver avant le chargement du client.
module Sentinel
  module Piste
    class Error < StandardError; end
    class NotConfigured < Error; end
  end
end
