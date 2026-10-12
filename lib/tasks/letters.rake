# Points d'entree scriptables de la page Courrier (utilises par Alfred) : une lettre
# s'ecrit par la skill write (contenu dans `body_text`), puis se rend ici.
#
# Arguments : ID (id de la Letter), OUT (chemin du fichier ; defaut tmp/letters/<nom>).
namespace :letters do
  find_letter = lambda do
    id = ENV["ID"].presence || abort("ID manquant : rake letters:pdf ID=3")
    Letter.find_by(id: id) || abort("Courrier ##{id} introuvable")
  end

  write_file = lambda do |letter, extension, data|
    path = ENV["OUT"].presence || Rails.root.join("tmp/letters/#{letter.base_filename}.#{extension}").to_s
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, data)
    puts path
  end

  desc "Genere le PDF d'un courrier : rake letters:pdf ID=3 [OUT=/chemin/lettre.pdf]"
  task pdf: :environment do
    letter = find_letter.call
    write_file.call(letter, "pdf", letter.to_pdf)
  end

  desc "Genere le DOCX d'un courrier : rake letters:docx ID=3 [OUT=/chemin/lettre.docx]"
  task docx: :environment do
    letter = find_letter.call
    write_file.call(letter, "docx", letter.to_docx)
  end

  desc "Range le PDF d'un courrier dans les documents (domaine letters, remplace le precedent) : rake letters:save_to_documents ID=3"
  task save_to_documents: :environment do
    document = find_letter.call.save_to_documents!
    puts "Document ##{document.id} : #{document.name}"
  end
end
