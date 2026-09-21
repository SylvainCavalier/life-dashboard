require "test_helper"

class PasswordChangeTest < ActionDispatch::IntegrationTest
  ANCIEN = "correct-horse-battery-staple".freeze
  NOUVEAU = "un-nouveau-mot-de-passe-solide".freeze

  test "la page est inaccessible sans session" do
    get account_password_path
    assert_redirected_to new_user_session_path
  end

  test "le proprietaire change son mot de passe et reste connecte" do
    user = create(:user, password: ANCIEN)
    sign_in(user)

    patch account_password_path, params: { user: {
      current_password: ANCIEN,
      password: NOUVEAU,
      password_confirmation: NOUVEAU
    } }

    assert_redirected_to root_path
    assert user.reload.valid_password?(NOUVEAU)

    # La session survit au changement : pas de deconnexion surprise.
    follow_redirect!
    assert_response :success
  end

  test "le nouveau mot de passe permet de se reconnecter" do
    user = create(:user, password: ANCIEN)
    sign_in(user)
    patch account_password_path, params: { user: {
      current_password: ANCIEN, password: NOUVEAU, password_confirmation: NOUVEAU
    } }
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: user.email, password: NOUVEAU } }
    assert_redirected_to root_path
  end

  test "un mauvais mot de passe actuel bloque le changement" do
    user = create(:user, password: ANCIEN)
    sign_in(user)

    patch account_password_path, params: { user: {
      current_password: "pas-le-bon-mot-de-passe",
      password: NOUVEAU,
      password_confirmation: NOUVEAU
    } }

    assert_response :unprocessable_entity
    assert user.reload.valid_password?(ANCIEN), "le mot de passe ne doit pas avoir change"
  end

  test "une confirmation qui ne correspond pas bloque le changement" do
    user = create(:user, password: ANCIEN)
    sign_in(user)

    patch account_password_path, params: { user: {
      current_password: ANCIEN,
      password: NOUVEAU,
      password_confirmation: "autre-chose-encore-plus-long"
    } }

    assert_response :unprocessable_entity
    assert user.reload.valid_password?(ANCIEN)
  end

  test "un mot de passe trop court est refuse" do
    user = create(:user, password: ANCIEN)
    sign_in(user)
    court = "a" * (Devise.password_length.min - 1)

    patch account_password_path, params: { user: {
      current_password: ANCIEN, password: court, password_confirmation: court
    } }

    assert_response :unprocessable_entity
    assert user.reload.valid_password?(ANCIEN)
  end

  test "le compte se verrouille apres cinq echecs de connexion" do
    user = create(:user, password: ANCIEN)

    Devise.maximum_attempts.times do
      post user_session_path, params: { user: { email: user.email, password: "mauvais" } }
    end

    assert user.reload.access_locked?

    post user_session_path, params: { user: { email: user.email, password: ANCIEN } }
    assert_nil controller.current_user, "un compte verrouille ne doit pas pouvoir se connecter"
  end
end
