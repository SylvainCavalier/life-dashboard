# Import d'un contrat d'assurance hors interface (Alfred local, debogage).
# Pas de `def` ici : une methode definie dans un fichier rake atterrit sur Object.
namespace :insurances do
  desc "Extrait la fiche d'un contrat (FILE=chemin.pdf) ; CREATE=1 cree l'assurance telle quelle"
  task import: :environment do
    path = ENV.fetch("FILE") { abort "FILE=chemin du contrat (PDF, JPEG, PNG, WebP) obligatoire" }
    abort "Fichier introuvable : #{path}" unless File.file?(path)

    content_type = Marcel::MimeType.for(Pathname.new(path), name: File.basename(path))
    import = InsuranceImport.new
    import.file.attach(io: File.open(path), filename: File.basename(path), content_type: content_type)
    import.save!
    InsuranceImportJob.perform_now(import.id)
    import.reload
    abort "Echec de l'extraction : #{import.error}" unless import.status == "done"

    draft = import.draft.deep_symbolize_keys
    puts JSON.pretty_generate(draft)
    if ENV["CREATE"] == "1"
      insurance = import.confirm!(**draft.slice(:insurance, :coverages, :items, :document))
      puts "Assurance ##{insurance.id} creee : /insurances/#{insurance.id}"
    else
      import.destroy
      puts "Brouillon seulement (CREATE=1 pour creer l'assurance)."
    end
  end
end
