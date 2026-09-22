# Alfred : recherche vectorielle (pgvector). Sur Heroku Postgres l'extension est
# disponible sur tous les plans ; en local elle s'installe avec PostgreSQL (voir DEPLOY.md).
class EnablePgvectorExtension < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector"
  end
end
