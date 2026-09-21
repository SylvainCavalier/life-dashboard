require "test_helper"

# Le compte est ouvert avec un mot de passe de bootstrap connu et faible. Ces
# tests garantissent qu'il ne peut servir qu'une fois : tant qu'il n'est pas
# remplace, rien d'autre n'est accessible.
class ForcedPasswordChangeTest < ActionDispatch::IntegrationTest
  SOLIDE = "un-mot-de-passe-vraiment-solide".freeze

  setup do
    User.delete_all
    @user = User.bootstrap!
  end

  test "le compte de bootstrap est cree avec le drapeau et le bon mot de passe" do
    assert @user.must_change_password?
    assert @user.valid_password?(User::BOOTSTRAP_PASSWORD)
    assert_equal "sylv.cavalier@gmail.com", @user.email
  end

  test "le mot de passe de bootstrap ne respecte pas la politique imposee ensuite" do
    # C'est precisement pour cela qu'il est cree sans validation et qu'il doit
    # etre remplace : si un jour il passait la validation, ce test le signale.
    assert User::BOOTSTRAP_PASSWORD.length < Devise.password_length.min
  end

  test "toute page redirige vers le changement de mot de passe" do
    sign_in @user

    ["/", "/contacts", "/passwords"].each do |path|
      get path
      assert_redirected_to account_password_path, "#{path} devrait forcer le changement"
    end
  end

  test "l'API est fermee tant que le mot de passe n'est pas change" do
    sign_in @user

    get "/api/contacts", headers: { "Accept" => "application/json" }
    assert_response :forbidden
    assert_equal account_password_path, response.parsed_body["redirect"]
  end

  test "la page de changement reste accessible, sans boucle de redirection" do
    sign_in @user

    get account_password_path
    assert_response :success
  end

  test "changer le mot de passe leve le blocage" do
    sign_in @user

    patch account_password_path, params: { user: {
      current_password: User::BOOTSTRAP_PASSWORD,
      password: SOLIDE,
      password_confirmation: SOLIDE
    } }
    assert_redirected_to root_path
    assert_not @user.reload.must_change_password?

    get root_path
    assert_response :success
  end

  test "un nouveau mot de passe trop court ne leve pas le blocage" do
    sign_in @user
    court = "a" * (Devise.password_length.min - 1)

    patch account_password_path, params: { user: {
      current_password: User::BOOTSTRAP_PASSWORD, password: court, password_confirmation: court
    } }

    assert_response :unprocessable_entity
    assert @user.reload.must_change_password?
    assert @user.valid_password?(User::BOOTSTRAP_PASSWORD)
  end

  test "le mot de passe de bootstrap ne peut pas etre reutilise comme nouveau mot de passe" do
    sign_in @user

    patch account_password_path, params: { user: {
      current_password: User::BOOTSTRAP_PASSWORD,
      password: User::BOOTSTRAP_PASSWORD,
      password_confirmation: User::BOOTSTRAP_PASSWORD
    } }

    assert_response :unprocessable_entity
    assert @user.reload.must_change_password?
  end

  test "la deconnexion reste possible depuis l'ecran bloquant" do
    sign_in @user
    delete destroy_user_session_path
    assert_redirected_to root_path

    get root_path
    assert_redirected_to new_user_session_path
  end

  test "la seed est idempotente" do
    assert_no_difference "User.count" do
      load Rails.root.join("db/seeds.rb")
    end
  end
end
