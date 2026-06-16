namespace :contacts do
  desc "Import contacts from an iOS vCard (.vcf) file. Usage: rake 'contacts:import_vcard[path,dry_run]'"
  task :import_vcard, [:path, :dry_run] => :environment do |_t, args|
    path = args[:path] or abort("Provide a .vcf path: rake 'contacts:import_vcard[/path/to/file.vcf,true]'")
    dry_run = args[:dry_run].to_s != "false"

    raw = File.read(path)
    # Unfold lines (RFC 6350: lines beginning with space/tab continue previous line)
    unfolded = raw.gsub(/\r?\n[ \t]/, "")

    cards = unfolded.scan(/BEGIN:VCARD(.*?)END:VCARD/m).map(&:first)

    parsed = cards.map { |c| parse_vcard(c) }.compact

    # Index existing DB contacts for dedup
    existing_by_name = {}
    existing_by_phone = {}
    Contact.find_each do |c|
      key = [c.first_name.to_s.strip.downcase, c.last_name.to_s.strip.downcase]
      existing_by_name[key] = c
      np = normalize_phone(c.phone)
      existing_by_phone[np] = c if np
    end

    # Manual skip list: phones of existing contacts whose phone is not yet in DB.
    # Alexia Picoulet (Contact #1) — phone not stored in her DB record but known from vCard.
    manual_skip_phones = [normalize_phone("+33646444129")].compact

    to_create = []
    skipped_existing = []
    skipped_invalid = []

    parsed.each do |attrs|
      if attrs[:first_name].blank? && attrs[:last_name].blank?
        skipped_invalid << attrs
        next
      end

      key = [attrs[:first_name].to_s.strip.downcase, attrs[:last_name].to_s.strip.downcase]
      np = normalize_phone(attrs[:phone])

      if existing_by_name[key] || (np && existing_by_phone[np]) || (np && manual_skip_phones.include?(np))
        skipped_existing << attrs
      else
        to_create << attrs
      end
    end

    puts "=" * 60
    puts "vCard parsed:        #{parsed.size}"
    puts "Already in DB:       #{skipped_existing.size}"
    puts "Invalid (no name):   #{skipped_invalid.size}"
    puts "To create:           #{to_create.size}"
    puts "=" * 60

    if skipped_existing.any?
      puts "\nSkipped (already in DB):"
      skipped_existing.each { |a| puts "  - #{a[:first_name]} #{a[:last_name]} (#{a[:phone] || a[:email] || 'no contact info'})" }
    end

    if skipped_invalid.any?
      puts "\nSkipped (no name in vCard):"
      skipped_invalid.first(5).each { |a| puts "  - phone=#{a[:phone].inspect} email=#{a[:email].inspect}" }
      puts "  ... +#{skipped_invalid.size - 5} more" if skipped_invalid.size > 5
    end

    puts "\nSample of contacts to create (first 10):"
    to_create.first(10).each do |a|
      summary = [a[:first_name], a[:last_name]].compact.join(" ")
      extras = []
      extras << "tel=#{a[:phone]}" if a[:phone]
      extras << "mail=#{a[:email]}" if a[:email]
      extras << "bday=#{a[:birth_date]}" if a[:birth_date]
      extras << "city=#{a[:city]}" if a[:city]
      extras << "job=#{a[:occupation]}" if a[:occupation]
      puts "  - #{summary} | #{extras.join(' | ')}"
    end

    if dry_run
      puts "\n[DRY RUN] No changes written. Re-run with dry_run=false to import."
      next
    end

    created = 0
    failed = []
    to_create.each do |attrs|
      attrs[:last_name] = "" if attrs[:last_name].blank?
      contact = Contact.new(attrs.merge(relationship_type: "connaissance"))
      if contact.save
        created += 1
      else
        failed << [attrs, contact.errors.full_messages]
      end
    end

    puts "\nCreated: #{created}"
    if failed.any?
      puts "Failed:  #{failed.size}"
      failed.first(10).each { |a, errs| puts "  - #{a[:first_name]} #{a[:last_name]}: #{errs.join(', ')}" }
    end
  end
end

def parse_vcard(body)
  attrs = {}
  body.each_line do |line|
    line = line.strip
    next if line.empty?
    # Strip item1./item2. prefix used by iOS
    line = line.sub(/\Aitem\d+\./, "")
    name, _, value = line.partition(":")
    next if value.empty?

    prop, *params = name.split(";")
    prop = prop.upcase
    params_str = params.join(";").upcase

    case prop
    when "N"
      parts = value.split(";")
      attrs[:last_name]  = unescape(parts[0]).presence
      attrs[:first_name] = unescape(parts[1]).presence
    when "FN"
      attrs[:_fn] = unescape(value)
    when "TEL"
      attrs[:phone] ||= clean_phone(value)
    when "EMAIL"
      attrs[:email] ||= unescape(value).strip.downcase
    when "BDAY"
      attrs[:birth_date] ||= parse_bday(value)
    when "ADR"
      parts = value.split(";").map { |p| unescape(p) }
      # ADR: pobox;extended;street;locality;region;postcode;country
      street = [parts[1], parts[2]].reject(&:blank?).join(" ").strip
      attrs[:address] ||= street.presence
      attrs[:city] ||= parts[3].presence
    when "ORG"
      attrs[:_org] = unescape(value.split(";").first)
    when "TITLE"
      attrs[:occupation] ||= unescape(value)
    when "IMPP", "X-SOCIALPROFILE"
      assign_social(attrs, params_str, value)
    when "URL"
      attrs[:_url] = unescape(value)
    end
  end

  # Fallback: derive first_name from FN if N didn't provide one
  if attrs[:first_name].blank? && attrs[:_fn]
    parts = attrs[:_fn].split(" ", 2)
    attrs[:first_name] = parts[0]
    attrs[:last_name] ||= parts[1]
  end

  # occupation fallback: use ORG if TITLE empty
  attrs[:occupation] ||= attrs[:_org] if attrs[:_org].present?

  attrs.delete(:_fn)
  attrs.delete(:_org)
  attrs.delete(:_url)
  attrs
end

def unescape(str)
  return nil if str.nil?
  str.gsub("\\,", ",").gsub("\\;", ";").gsub("\\n", "\n").strip
end

def clean_phone(raw)
  v = unescape(raw)
  return nil if v.blank?
  v.strip
end

def normalize_phone(raw)
  return nil if raw.blank?
  digits = raw.gsub(/\D/, "")
  return nil if digits.empty?
  # Strip French country code 33 if number starts with it and is 11 digits
  digits = digits.sub(/\A33/, "0") if digits.length == 11 && digits.start_with?("33")
  # Strip leading 0
  digits.sub(/\A0+/, "")
end

def parse_bday(raw)
  v = raw.sub(/\Avalue=date:/i, "").strip
  return nil if v.blank?
  # Common formats: YYYY-MM-DD, YYYYMMDD, --MMDD
  case v
  when /\A(\d{4})-?(\d{2})-?(\d{2})\z/
    y, m, d = $1.to_i, $2.to_i, $3.to_i
    return nil if y < 1900 || y > Date.today.year
    Date.new(y, m, d) rescue nil
  else
    nil
  end
end

def assign_social(attrs, params_str, value)
  v = unescape(value).sub(/\Axmpp:/, "").sub(/\Ahttps?:\/\//, "")
  service = case params_str
            when /FACEBOOK/ then :social_facebook
            when /INSTAGRAM/ then :social_instagram
            when /TWITTER/ then :social_twitter
            when /LINKEDIN/ then :social_linkedin
            when /TIKTOK/ then :social_tiktok
            when /SNAPCHAT/ then :social_snapchat
            when /YOUTUBE/ then :social_youtube
            end
  attrs[service] ||= v if service
end
