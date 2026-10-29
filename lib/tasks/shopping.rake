# Points d'entree scriptables de la page Courses (utilises par l'Alfred local) : la
# skill write ne sait ni ajouter un lot d'articles en ignorant les doublons, ni retirer
# un article ou vider la liste (pas de suppression), d'ou ces taches.
namespace :shopping do
  desc "Affiche la liste de courses"
  task list: :environment do
    items = ShoppingItem.ordered.to_a
    puts "Liste vide" if items.empty?
    items.each { |item| puts "#{item.checked? ? '[x]' : '[ ]'} ##{item.id} #{item.name}" }
  end

  desc "Ajoute des articles : rake shopping:add ITEMS=\"Lait, Oeufs, Pain\""
  task add: :environment do
    names = ENV["ITEMS"].to_s.split(/[,;\n]/)
    abort("ITEMS manquant : rake shopping:add ITEMS=\"Lait, Oeufs\"") if names.all?(&:blank?)

    added, skipped = ShoppingItem.add_names(names)
    puts "Ajoute(s) : #{added.map(&:name).join(', ')}" if added.any?
    puts "Deja dans la liste : #{skipped.join(', ')}" if skipped.any?
  end

  desc "Retire des articles (casse ignoree) : rake shopping:remove ITEMS=\"Pain\""
  task remove: :environment do
    names = ENV["ITEMS"].to_s.split(/[,;\n]/).map(&:squish).compact_blank.map(&:downcase)
    abort("ITEMS manquant : rake shopping:remove ITEMS=\"Pain\"") if names.empty?

    removed = ShoppingItem.where("lower(name) IN (?)", names).destroy_all
    puts removed.any? ? "Retire(s) : #{removed.map(&:name).join(', ')}" : "Aucun de ces articles dans la liste"
  end

  desc "Vide la liste de courses (apres les courses) : rake shopping:clear"
  task clear: :environment do
    puts "#{ShoppingItem.clear!} article(s) retire(s)"
  end
end
