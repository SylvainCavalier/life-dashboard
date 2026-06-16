namespace :contacts do
  desc "Guess gender (homme/femme) from first_name for contacts where gender is nil. Usage: rake 'contacts:guess_gender[dry_run]'"
  task :guess_gender, [:dry_run] => :environment do |_t, args|
    require "gender_detector"
    dry_run = args[:dry_run].to_s != "false"

    detector = GenderDetector.new(case_sensitive: false)

    targets = Contact.where(gender: [nil, ""])
    puts "Contacts without gender: #{targets.count}"

    decisions = { male: [], female: [], ambiguous: [], unknown: [] }

    targets.find_each do |c|
      # Use only the first token of first_name (handles "Jean-Pierre", "Marie Claire")
      first = c.first_name.to_s.split(/[\s\-]/).first.to_s.strip
      next if first.blank? || first == "?"

      # Try France-specific first, then fallback to any country
      result = detector.get_gender(first, :france)
      result = detector.get_gender(first) if result == :unknown

      case result
      when :male, :mostly_male
        decisions[:male] << [c, first, result]
      when :female, :mostly_female
        decisions[:female] << [c, first, result]
      when :andy
        decisions[:ambiguous] << [c, first]
      else
        decisions[:unknown] << [c, first]
      end
    end

    puts "=" * 60
    puts "homme:      #{decisions[:male].size}"
    puts "femme:      #{decisions[:female].size}"
    puts "ambigu:     #{decisions[:ambiguous].size} (laissés vides)"
    puts "inconnu:    #{decisions[:unknown].size} (laissés vides)"
    puts "=" * 60

    puts "\nSample homme (10):"
    decisions[:male].first(10).each { |c, fn, r| puts "  - #{c.first_name} #{c.last_name} (#{fn} → #{r})" }
    puts "\nSample femme (10):"
    decisions[:female].first(10).each { |c, fn, r| puts "  - #{c.first_name} #{c.last_name} (#{fn} → #{r})" }
    puts "\nSample ambigu (10):"
    decisions[:ambiguous].first(10).each { |c, fn| puts "  - #{c.first_name} #{c.last_name} (#{fn})" }
    puts "\nSample inconnu (10):"
    decisions[:unknown].first(10).each { |c, fn| puts "  - #{c.first_name} #{c.last_name} (#{fn})" }

    if dry_run
      puts "\n[DRY RUN] No changes written. Re-run with dry_run=false to apply."
      next
    end

    updated = 0
    decisions[:male].each   { |c, _, _| updated += 1 if c.update(gender: "homme") }
    decisions[:female].each { |c, _, _| updated += 1 if c.update(gender: "femme") }
    puts "\nUpdated: #{updated} contacts"
  end
end
