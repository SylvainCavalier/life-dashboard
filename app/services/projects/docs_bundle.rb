require "zlib"

module Projects
  # Range la documentation des depots de code (CLAUDE.md, .knowledge/history.md,
  # .knowledge/marketing.md) dans les documents des projets du dashboard.
  #
  # Deux temps, parce que les depots ne vivent que sur le Mac :
  # 1. `build` lit les depots et produit un paquet JSON gzippe (rien en base) ;
  # 2. `import!` le rejoue sur n'importe quelle base, production comprise
  #    (`heroku run ... < paquet`). Idempotent : un document deja present n'est
  #    remplace que si le fichier a change, un projet absent est cree.
  #
  # Le paquet ne passe jamais par git : le depot du dashboard est public.
  class DocsBundle
    FILES = {
      "CLAUDE.md" => "CLAUDE.md",
      ".knowledge/history.md" => "history.md",
      ".knowledge/marketing.md" => "marketing.md"
    }.freeze

    # Dossier => projet du dashboard. `create` sert seulement si aucun projet ne
    # porte ce nom (ni cette URL GitHub). Les depots dont le CLAUDE.md est celui du
    # boilerplate sans retouche (logijuris, loup, quizator, csrd...) sont omis.
    REPOSITORIES = {
      "prudo" => { name: "Prudo" },
      "glucksbot" => { name: "Glucksbot" },
      "langochat" => { name: "Langochat" },
      "life-dashboard" => { name: "Life Dashboard" },
      "conspi" => { name: "Conspi.fr" },
      "diplomatica" => { name: "Diplomatica" },
      "talely" => { name: "Talely" },
      "rogue_dungeons" => { name: "Rogue Dungeons" },
      "poudlard" => { name: "Poudlard" },
      "narval" => { name: "Narval" },
      "imagenx" => { name: "Imagenx" },
      "SW-JDR" => { name: "SW-JDR" },
      "portfolio" => { name: "Portfolio" },
      "sbc-labs" => {
        name: "SBC Labs",
        create: { status: "en_cours", description: "Site vitrine de SBC Labs, l'activité de développement web (sbclabs.fr)", site_url: "https://sbclabs.fr" }
      },
      "demo-app" => {
        name: "Demo App",
        create: { status: "en_cours", description: "Catalogue de démonstrations des services proposés aux prospects (audit, CRM, chatbot RAG, extraction PDF, veille)" }
      },
      "stargate" => {
        name: "Stargate",
        create: { status: "en_cours", category: "jeu_video", description: "Fangame de gestion tour par tour inspiré de la série : le joueur dirige le SGC à partir de 1997" }
      },
      "Conquest" => {
        name: "Conquest",
        create: { status: "en_attente", category: "jeu_video", description: "Jeu textuel de stratégie par navigateur : gérer et développer un royaume" }
      },
      "netflop" => {
        name: "Netflop",
        create: { status: "en_attente", description: "Plateforme de streaming façon Netflix : films, séries, épisodes, reprise de lecture" }
      },
      "observations" => {
        name: "Observations",
        create: { status: "en_attente", description: "Plateforme d'observation de la faune : sites, observations d'espèces, territoires" }
      },
      "citizenfacts" => {
        name: "CitizenFacts",
        create: { status: "en_attente", description: "Plateforme de fact-checking : enquêtes, indices et dossiers de preuves" }
      },
      "sw-siege" => {
        name: "SW Siege",
        create: { status: "en_attente", description: "Outil d'aide pour une guilde Summoners War: Sky Arena (sièges de guilde)" }
      },
      "SW-Crediter" => {
        name: "SW-Crediter",
        create: { status: "en_attente", description: "Comlink Star Wars sur smartphone pour les joueurs d'un GN" }
      },
      "FakeNewsletter" => {
        name: "FakeNewsletter",
        create: { status: "en_attente", description: "Newsletter d'articles sur la désinformation, collectés par recherche Google et triés par ChatGPT" }
      },
      "video-downloader" => {
        name: "Video Downloader",
        create: { status: "termine", description: "Téléchargeur YouTube autonome, depuis intégré au Life Dashboard (module Downloader)" }
      }
    }.freeze

    def self.build(root)
      projects = REPOSITORIES.filter_map do |folder, config|
        dir = File.join(root, folder)
        files = FILES.filter_map do |relative, label|
          path = File.join(dir, relative)
          next unless File.file?(path)

          { label: label, source: "#{folder}/#{relative}", content: File.read(path),
            modified_on: File.mtime(path).to_date.iso8601 }
        end
        next if files.empty?

        { folder: folder, name: config[:name], github_url: github_url(dir),
          create: config.fetch(:create, nil), files: files }
      end
      Zlib.gzip({ generated_at: Time.current.iso8601, projects: projects }.to_json)
    end

    def self.github_url(dir)
      url = `git -C #{dir.shellescape} remote get-url origin 2>/dev/null`.strip
      return if url.blank?

      url.sub(/\Agit@github\.com:/, "https://github.com/").delete_suffix(".git")
    end

    def initialize(gzipped, dry_run: false, log: $stdout)
      @data = JSON.parse(Zlib.gunzip(gzipped))
      @dry_run = dry_run
      @log = log
    end

    def import!
      counts = Hash.new(0)
      @data["projects"].each do |entry|
        project = find_or_create_project(entry, counts)
        next unless project

        entry["files"].each { |file| counts[sync_document(project, entry, file)] += 1 }
      end
      counts
    end

    private

    def find_or_create_project(entry, counts)
      project = Project.where("LOWER(name) = ?", entry["name"].downcase).first
      project ||= Project.find_by(github_url: entry["github_url"]) if entry["github_url"]
      return project if project

      unless entry["create"]
        @log.puts "  ! #{entry['name']} : projet introuvable, ignore"
        counts[:missing_project] += 1
        return
      end

      @log.puts "  + projet #{entry['name']}"
      counts[:created_project] += 1
      return Project.new(name: entry["name"]) if @dry_run

      Project.create!(entry["create"].merge("name" => entry["name"], "github_url" => entry["github_url"]))
    end

    def sync_document(project, entry, file)
      name = "#{entry['name']} - #{file['label']}"
      checksum = OpenSSL::Digest::MD5.base64digest(file["content"])
      document = project.persisted? ? project.documents.find_by(name: name) : nil
      return :unchanged if document&.file&.attached? && document.file.checksum == checksum

      action = document ? :updated : :created
      @log.puts "    #{action == :created ? '+' : '~'} #{name}"
      return action if @dry_run

      document ||= project.documents.build(name: name, domain: "projects", category: "reference")
      document.assign_attributes(document_date: file["modified_on"], notes: "Importé depuis #{file['source']}")
      document.file.attach(io: StringIO.new(file["content"]), filename: file["label"], content_type: "text/markdown")
      document.save!
      action
    end
  end
end
