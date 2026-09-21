# Configuration CORS du bucket OVH Object Storage.
# Indispensable pour le direct upload Active Storage : le navigateur envoie le
# fichier en PUT directement sur le bucket, ce que le bucket refuse tant que
# l'origine de l'app n'est pas autorisee.
#
#   rake ovh:cors:show
#   rake ovh:cors:setup ORIGINS=https://mon-dashboard.fr
#
# ORIGINS accepte plusieurs valeurs separees par des virgules.
# http://localhost:3000 est toujours ajoute pour le developpement.
namespace :ovh do
  namespace :cors do
    desc "Affiche la configuration CORS actuelle du bucket OVH"
    task show: :environment do
      client = ovh_s3_client
      bucket = ENV.fetch("OVH_S3_BUCKET")

      begin
        rules = client.get_bucket_cors(bucket: bucket).cors_rules
        puts "Regles CORS sur #{bucket} :"
        rules.each_with_index do |rule, i|
          puts "  [#{i}] origins=#{rule.allowed_origins.inspect} methods=#{rule.allowed_methods.inspect} " \
               "headers=#{rule.allowed_headers.inspect} expose=#{rule.expose_headers.inspect} max_age=#{rule.max_age_seconds}"
        end
      rescue Aws::S3::Errors::NoSuchCORSConfiguration
        puts "Aucune configuration CORS sur #{bucket}."
      end
    end

    desc "Configure le CORS du bucket OVH pour le direct upload (ORIGINS=https://...)"
    task setup: :environment do
      client = ovh_s3_client
      bucket = ENV.fetch("OVH_S3_BUCKET")
      dev_origins = [ "http://localhost:3000", "http://127.0.0.1:3000" ]
      origins = (ENV["ORIGINS"].to_s.split(",").map(&:strip).reject(&:empty?) + dev_origins).uniq

      client.put_bucket_cors(
        bucket: bucket,
        cors_configuration: {
          cors_rules: [
            {
              allowed_headers: [ "*" ],
              allowed_methods: [ "PUT", "GET", "HEAD" ],
              allowed_origins: origins,
              expose_headers: [ "Origin", "Content-Type", "Content-MD5", "Content-Disposition", "ETag" ],
              max_age_seconds: 3600
            }
          ]
        }
      )

      puts "CORS configure sur #{bucket} pour : #{origins.join(', ')}"
    end
  end
end

def ovh_s3_client
  require "aws-sdk-s3"

  Aws::S3::Client.new(
    access_key_id: ENV.fetch("OVH_S3_ACCESS_KEY"),
    secret_access_key: ENV.fetch("OVH_S3_SECRET_KEY"),
    region: ENV.fetch("OVH_S3_REGION", "gra"),
    endpoint: ENV.fetch("OVH_S3_ENDPOINT"),
    force_path_style: true
  )
end
