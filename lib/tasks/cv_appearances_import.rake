namespace :cv do
  desc "Importe les interventions publiques depuis db/cv_appearances.yml dans CvExperience"
  task import_appearances: :environment do
    require "yaml"

    file = Rails.root.join("db/cv_appearances.yml")
    data = YAML.load_file(file, permitted_classes: [])

    appearances = data["cv_appearances"]
    puts "#{appearances.size} entrées trouvées."

    skipped = 0
    created = 0

    appearances.each do |entry|
      if CvExperience.exists?(title: entry["title"], company: entry["company"], start_year: entry["start_year"])
        skipped += 1
        next
      end

      CvExperience.create!(
        title:       entry["title"],
        company:     entry["company"],
        location:    entry["location"],
        description: entry["description"]&.strip,
        start_year:  entry["start_year"],
        end_year:    entry["end_year"],
        category:    "intervention",
        domain:      ["desinformation"]
      )
      created += 1
    end

    puts "#{created} créées, #{skipped} ignorées (déjà présentes)."
  end
end
