require "test_helper"

class CvPitchesTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
  end

  test "creation d'une accroche, activee sur demande" do
    assert_difference "CvPitch.count", 1 do
      post api_cv_pitches_path,
           params: { cv_pitch: { title: "Dev", content: "Developpeur Rails." }, activate: true }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    pitch = CvPitch.find(JSON.parse(response.body)["id"])
    assert_equal pitch, CvSetting.singleton.active_pitch

    post api_cv_pitches_path,
         params: { cv_pitch: { title: "Juriste", content: "Juriste en droit social." } }.to_json,
         headers: JSON_HEADERS
    assert_equal pitch, CvSetting.singleton.reload.active_pitch, "sans activate, l'accroche active ne change pas"
  end

  test "une accroche sans texte repond 422" do
    post api_cv_pitches_path, params: { cv_pitch: { title: "Vide", content: "" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "changer d'accroche affichee sans perdre les autres" do
    dev = CvPitch.create!(title: "Dev", content: "Developpeur Rails.")
    law = CvPitch.create!(title: "Juriste", content: "Juriste en droit social.")
    CvSetting.singleton.update!(active_pitch: dev)

    patch api_cv_setting_path, params: { cv_setting: { active_pitch_id: law.id } }.to_json, headers: JSON_HEADERS
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal law.id, body["active_pitch_id"]
    assert_equal "Juriste en droit social.", body["pitch"]
    assert CvPitch.exists?(dev.id)

    get api_cv_data_path, headers: JSON_HEADERS
    data = JSON.parse(response.body)
    assert_equal 2, data["pitches"].size
    assert_equal "Juriste en droit social.", data["settings"]["pitch"]
  end

  test "une accroche inexistante est refusee" do
    patch api_cv_setting_path, params: { cv_setting: { active_pitch_id: 0 } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "supprimer l'accroche active laisse le CV sans accroche" do
    dev = CvPitch.create!(title: "Dev", content: "Developpeur Rails.")
    CvSetting.singleton.update!(active_pitch: dev)

    delete api_cv_pitch_path(dev), headers: JSON_HEADERS
    assert_response :no_content
    setting = CvSetting.singleton.reload
    assert_nil setting.active_pitch_id
    assert_nil setting.pitch
  end
end
