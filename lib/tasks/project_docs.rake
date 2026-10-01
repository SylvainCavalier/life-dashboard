# Documentation des depots de code (CLAUDE.md, history.md, marketing.md) rangee
# dans les documents des projets. Voir Projects::DocsBundle.
#
#   bin/rails projects:docs_bundle                       # lit ~/code/SylvainCavalier, ecrit tmp/project_docs.json.gz
#   bin/rails projects:import_docs DRY_RUN=1             # montre ce qui serait fait
#   bin/rails projects:import_docs                       # importe (idempotent)
#   heroku run --no-tty -x 'bin/rails projects:import_docs FILE=-' < tmp/project_docs.json.gz   # production
namespace :projects do
  desc "Construit le paquet de documentation des depots (ROOT=~/code/SylvainCavalier OUT=tmp/project_docs.json.gz)"
  task docs_bundle: :environment do
    root = File.expand_path(ENV.fetch("ROOT", "~/code/SylvainCavalier"))
    out = ENV.fetch("OUT", Rails.root.join("tmp/project_docs.json.gz").to_s)
    File.binwrite(out, Projects::DocsBundle.build(root))
    puts "Paquet ecrit : #{out} (#{File.size(out) / 1024} Ko)"
  end

  desc "Importe le paquet dans les projets (FILE=tmp/project_docs.json.gz, FILE=- pour l'entree standard, DRY_RUN=1)"
  task import_docs: :environment do
    file = ENV.fetch("FILE", Rails.root.join("tmp/project_docs.json.gz").to_s)
    gzipped = file == "-" ? $stdin.binmode.read : File.binread(file)
    dry_run = ENV["DRY_RUN"] == "1"
    counts = Projects::DocsBundle.new(gzipped, dry_run: dry_run).import!
    puts "#{dry_run ? '[simulation] ' : ''}#{counts.map { |k, v| "#{k}: #{v}" }.join(', ')}"
  end
end
