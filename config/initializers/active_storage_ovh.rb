require "aws-sdk-s3"

# OVH's S3-compatible API redirects some requests to URLs using uppercase region
# names (e.g. s3.GRA.io.cloud.ovh.net). The AWS SDK's Redirects plugin follows
# these and re-signs with the uppercase region, which OVH then rejects.
# Removing the plugin prevents this retry-redirect loop.
Aws::S3::Client.remove_plugin(Aws::S3::Plugins::Redirects)
