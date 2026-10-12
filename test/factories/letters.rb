# == Schema Information
#
# Table name: letters
#
#  id                :bigint           not null, primary key
#  body              :jsonb            not null
#  footer            :text
#  include_signature :boolean          default(TRUE), not null
#  letter_date       :date
#  mention           :string
#  place             :string
#  recipient         :text
#  reference         :string
#  sender            :text
#  signatory         :string
#  subject           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#
# Indexes
#
#  index_letters_on_document_id  (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :letter do
    sender { "Sylvain Cavalier\n12 rue des Lilas\n94000 Créteil" }
    recipient { "Free - Service Résiliation\n75371 Paris Cedex 08" }
    place { "Créteil" }
    letter_date { Date.new(2026, 10, 12) }
    mention { "Lettre recommandée avec accusé de réception" }
    subject { "Résiliation de mon abonnement" }
    body_text { "Madame, Monsieur,\n\nJe résilie mon contrat.\n\nSalutations distinguées." }
    signatory { "Sylvain Cavalier" }
    include_signature { false }
    footer { "SIRET 123 456 789 00010" }
  end
end
