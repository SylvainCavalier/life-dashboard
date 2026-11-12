module Projects
  # Devine, sans modele, le projet et l'interlocuteur dont parle un texte court (titre et
  # description d'un rendez-vous, participants d'une reunion). Volontairement prudent :
  # un seul candidat ou rien, jamais de choix au hasard entre deux.
  #
  # Projet : nom d'un projet actif cite en mot entier, sinon nom complet d'un contact lie
  # (ProjectContact) a un seul projet actif. Contact : nom complet cite, parmi les
  # contacts du projet d'abord, puis parmi tous les contacts.
  class Matcher
    MIN_NAME_LENGTH = 4

    def initialize(text)
      @text = normalize(text)
    end

    def project
      return if @text.blank?

      by_name = Project.active.select { |project| project.name.to_s.length >= MIN_NAME_LENGTH && cites?(project.name) }
      return by_name.first if by_name.one?
      return if by_name.many?

      linked = ProjectContact.joins(:project).merge(Project.active).includes(:contact, :project)
                             .select { |link| cites?(full_name(link.contact)) }
      projects = linked.map(&:project).uniq
      projects.first if projects.one?
    end

    def contact(project = nil)
      return if @text.blank?

      if project
        found = project.contacts.select { |contact| cites?(full_name(contact)) }
        return found.first if found.one?
        return if found.many?
      end

      found = Contact.where.not(first_name: [nil, ""]).where.not(last_name: [nil, ""])
                     .select(:id, :first_name, :last_name).select { |contact| cites?(full_name(contact)) }
      Contact.find(found.first.id) if found.one?
    end

    private

    # Prenom ET nom : un prenom seul (« Paul ») designe trop de monde.
    def full_name(contact)
      return if contact.first_name.blank? || contact.last_name.blank?

      "#{contact.first_name} #{contact.last_name}"
    end

    # Mot entier, sans tenir compte de la casse ni des accents.
    def cites?(name)
      return false if name.blank?

      needle = normalize(name)
      return false if needle.length < MIN_NAME_LENGTH

      @text.match?(/(?<![[:alnum:]])#{Regexp.escape(needle)}(?![[:alnum:]])/)
    end

    def normalize(text)
      Alfred::AccentFolding.fold(text).downcase.gsub(/\s+/, " ").strip
    end
  end
end
