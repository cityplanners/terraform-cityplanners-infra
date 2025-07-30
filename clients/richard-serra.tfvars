project_name             = "richard-serra"
atlas_cluster_name       = "cityplanners"
use_payload              = true
domain_name              = "richardserra.site"
domain_registered_in_aws = false
route53_zone_id          = ""
containers = [
  {
    name  = "payload"
    image = "payloadcms/payload:latest"
    port  = 3000
    secrets = {
      PAYLOAD_SECRET = "arn:aws:ssm:us-east-1:643208527070:parameter/clients/richard-serra/payload_secret"
      MONGODB_URI    = "arn:aws:ssm:us-east-1:643208527070:parameter/clients/richard-serra/mongodb_uri"
    }
    environment = {
      NODE_ENV = "production"
    }
  }
]
