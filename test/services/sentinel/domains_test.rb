require "test_helper"

class Sentinel::DomainsTest < ActiveSupport::TestCase
  test "le registre expose les deux domaines, avec des cles uniques" do
    assert_equal %w[droit_travail desinformation], Sentinel::Domains.keys
    assert_nil Sentinel::Domains.find("cuisine")
    assert_raises(Sentinel::Domains::UnknownDomain) { Sentinel::Domains.find!("cuisine") }
  end

  test "chaque domaine remplit tout le contrat" do
    Sentinel::Domains.all.each do |domain|
      %i[key label icon description summary_persona importance_scale digest_persona].each do |method|
        assert domain.public_send(method).present?, "#{domain.class}##{method}"
      end
      assert domain.kinds.any?
      assert domain.categories.any?
      assert domain.default_sources.any?
    end
  end

  test "droit du travail : un texte Legifrance est retenu par son NOR ou par un motif, sinon ecarte" do
    domain = Sentinel::Domains.find!("droit_travail")
    source = build(:sentinel_source, :legifrance)

    by_nor = build(:sentinel_document, sentinel_source: source, title: "Arrêté du 17 septembre 2026",
                                       raw_content: "", raw_metadata: { "nor" => "MTRT2612345A" })
    assert domain.classify(by_nor).relevant
    assert_equal "nor_prefix:MTR", domain.classify(by_nor).reason

    by_pattern = build(:sentinel_document, sentinel_source: source, raw_metadata: { "nor" => "ECOX1" },
                                           title: "Décret relatif à la durée du travail dans les transports")
    assert domain.classify(by_pattern).relevant

    unrelated = build(:sentinel_document, sentinel_source: source, raw_metadata: { "nor" => "ARML2624364A" },
                                          title: "Arrêté portant création d'une zone interdite temporaire",
                                          raw_content: "Espace aérien.")
    assert_not domain.classify(unrelated).relevant
    assert_equal "no_signal", domain.classify(unrelated).reason
  end

  test "droit du travail : une source specialisee est retenue d'office" do
    domain = Sentinel::Domains.find!("droit_travail")
    document = build(:sentinel_document, sentinel_source: build(:sentinel_source, :judilibre), title: "Cass. soc.")
    assert domain.classify(document).relevant
  end

  test "desinformation : une source generaliste est filtree par mots-cles" do
    domain = Sentinel::Domains.find!("desinformation")
    source = build(:sentinel_source, :generalist)

    kept = build(:sentinel_document, sentinel_source: source, title: "Une théorie du complot sur les vaccins",
                                     raw_content: "Les complotistes relaient une infox.")
    dropped = build(:sentinel_document, sentinel_source: source, title: "Résultats de la Ligue 1",
                                        raw_content: "Le PSG s'impose à domicile.")
    assert domain.classify(kept).relevant
    assert_not domain.classify(dropped).relevant
  end
end
