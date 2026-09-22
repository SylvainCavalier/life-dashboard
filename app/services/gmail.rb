# Gestion des mails de Sylvain par Alfred (agent du dashboard), via l'API Gmail.
#
# Pas de module Messagerie synchronise : rien n'est copie en base ni dans le
# corpus RAG, Alfred interroge Gmail en direct avec ses outils (recherche,
# lecture, tri, redaction) et toute ecriture (envoi, brouillon, tri) passe par
# une AlfredAction confirmee dans le chat, comme les ecritures en base.
#
# Acces : le compte de service de l'application (GoogleServiceAccount) incarne
# GMAIL_USER grace a la delegation au niveau du domaine Workspace (console
# d'administration > Securite > Commandes des API > Delegation au niveau du
# domaine : identifiant client du compte de service + SCOPE). Procedure dans DEPLOY.md.
module Gmail
  # Tout sauf la suppression definitive (qui contourne la corbeille) : lecture,
  # libelles, archivage, corbeille, brouillons et envoi.
  SCOPE = "https://www.googleapis.com/auth/gmail.modify".freeze
  NOT_CONFIGURED = "Gmail n'est pas configure sur ce serveur (GMAIL_USER et cle du compte de service).".freeze

  # La boite GMAIL_USER centralise les sept adresses de Sylvain : chaque mail
  # recu porte, par filtre Gmail, le libelle de sa boite d'origine. Source unique
  # pour le prompt d'Alfred (choix de l'adresse d'envoi, tri par importance).
  MAILBOXES = [
    { label: "SBC", address: "admin@sbclabs.fr", role: "gestion de l'entreprise SBC Labs ; c'est la boite centrale" },
    { label: "Cavalier", address: "mail@sylvaincavalier.com", role: "portfolio et contact professionnel de developpeur freelance" },
    { label: "Prudo", address: "sylvain@prudo.fr (ou contact@prudo.fr)", role: "application Prudo (litiges prud'homaux)" },
    { label: "ICP", address: "sy.bertrand@chens.icp.fr", role: "enseignement du droit du travail a la faculte de l'ICP" },
    { label: "Debunker", address: "sylv.cavalier@gmail.com", role: "desinformation et debunkage (Debunker des Etoiles)" },
    { label: "Orange", address: "sylv.bertrand@orange.fr", role: "premiere adresse, sites officiels et demarches administratives" },
    { label: "Pingouin", address: "lucien.le.pingouin@gmail.com", role: "jeux et loisirs, rarement important" }
  ].freeze

  module_function

  def user
    ENV["GMAIL_USER"].presence
  end

  def enabled?
    GoogleServiceAccount.configured? && user.present?
  end

  # Point d'entree unique des outils d'Alfred (remplacable en test).
  def client
    Client.new
  end
end
