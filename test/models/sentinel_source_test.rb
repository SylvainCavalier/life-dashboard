# == Schema Information
#
# Table name: sentinel_sources
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(TRUE), not null
#  adapter              :string
#  domain               :string           not null
#  feed_url             :string
#  language             :string           default("fr"), not null
#  last_collected_at    :datetime
#  last_documents_count :integer
#  last_error           :text
#  name                 :string           not null
#  on_topic             :boolean          default(FALSE), not null
#  slug                 :string           not null
#  url                  :string
#  web_search           :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_sentinel_sources_on_domain_and_slug  (domain,slug) UNIQUE
#
require "test_helper"

class SentinelSourceTest < ActiveSupport::TestCase
  test "une source doit avoir au moins un canal de collecte" do
    source = build(:sentinel_source, feed_url: nil, web_search: false, adapter: nil)
    assert_not source.valid?
  end

  test "la recherche web exige l'adresse du site" do
    assert_not build(:sentinel_source, :web_only, url: nil).valid?
  end

  test "le slug est deduit du nom et unique par domaine" do
    source = create(:sentinel_source, name: "Conspiracy Watch", slug: nil)
    assert_equal "conspiracy_watch", source.slug
    assert_not build(:sentinel_source, slug: "conspiracy_watch").valid?
    assert build(:sentinel_source, slug: "conspiracy_watch", domain: "droit_travail").valid?
  end

  test "host retire le www" do
    assert_equal "lemonde.fr", build(:sentinel_source, url: "https://www.lemonde.fr/les-decodeurs/").host
  end

  test "seed_defaults! est idempotent et n'ecrase pas les reglages manuels" do
    added = SentinelSource.seed_defaults!("droit_travail")
    assert_equal 3, added

    SentinelSource.find_by!(slug: "village_justice").update!(active: false)
    assert_equal 0, SentinelSource.seed_defaults!("droit_travail")
    assert_not SentinelSource.find_by!(slug: "village_justice").active
  end

  test "les sources par defaut de chaque domaine sont valides" do
    Sentinel::Domains.all.each do |domain|
      domain.default_sources.each do |attributes|
        source = SentinelSource.new(attributes.merge(domain: domain.key))
        assert source.valid?, "#{domain.key}/#{attributes[:slug]} : #{source.errors.full_messages.join(', ')}"
      end
      slugs = domain.default_sources.pluck(:slug)
      assert_equal slugs.uniq, slugs, "slugs en double dans #{domain.key}"
    end
  end

  test "bootstrap! ne re-remplit pas un domaine deja utilise" do
    create(:sentinel_week)
    assert_equal 0, SentinelSource.bootstrap!("desinformation")
    assert_not SentinelSource.for_domain("desinformation").exists?
  end
end
