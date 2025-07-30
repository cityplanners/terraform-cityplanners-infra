#!/bin/bash

# Usage: ./create-client-secrets.sh richard-serra

CLIENT_NAME=$1
REGION="us-east-1"
CLUSTER_NAME="cityplanners"

if [[ -z "$CLIENT_NAME" ]]; then
  echo "Usage: $0 <client-name>"
  exit 1
fi

read -p "Will this client use Payload CMS? (y/n): " USE_PAYLOAD

USE_PAYLOAD_FLAG="false"
if [[ "$USE_PAYLOAD" =~ ^[Yy]$ ]]; then
  USE_PAYLOAD_FLAG="true"

  # Prompt for and store MongoDB password
  read -sp "Enter MongoDB DB password for $CLIENT_NAME: " DB_PASS
  echo ""

  aws ssm put-parameter \
    --name "/clients/${CLIENT_NAME}/mongodb-password" \
    --type "SecureString" \
    --value "${DB_PASS}" \
    --overwrite \
    --region $REGION

  # Construct and store the MongoDB URI
  MONGODB_URI="mongodb+srv://payload-${CLIENT_NAME}:${DB_PASS}@${CLUSTER_NAME}.mongodb.net/${CLIENT_NAME}"

  aws ssm put-parameter \
    --name "/clients/${CLIENT_NAME}/mongodb_uri" \
    --type "SecureString" \
    --value "${MONGODB_URI}" \
    --overwrite \
    --region $REGION

  # Generate and store Payload secret automatically
  PAYLOAD_SECRET=$(openssl rand -hex 32)
  echo "Generated Payload secret for ${CLIENT_NAME}"

  aws ssm put-parameter \
    --name "/clients/${CLIENT_NAME}/payload_secret" \
    --type "SecureString" \
    --value "${PAYLOAD_SECRET}" \
    --overwrite \
    --region $REGION
fi

# SSM ARNs aren't returned directly — we manually construct the reference path
get_ssm_arn() {
  local name="$1"
  echo "arn:aws:ssm:${REGION}:$(aws sts get-caller-identity --query Account --output text):parameter${name}"
}

read -p "Enter custom domain name for ${CLIENT_NAME}: " DOMAIN_NAME

read -p "Is the domain registered in AWS Route 53? (y/n): " USE_AWS_DOMAIN
if [[ "$USE_AWS_DOMAIN" =~ ^[Yy]$ ]]; then
  DOMAIN_IN_AWS=true
  read -p "Enter Route 53 Hosted Zone ID: " ROUTE53_ZONE_ID
else
  DOMAIN_IN_AWS=false
  ROUTE53_ZONE_ID=""
fi

# Write the tfvars file
TFVARS_FILE="clients/${CLIENT_NAME}.tfvars"
{
  echo "project_name             = \"${CLIENT_NAME}\""
  echo "atlas_cluster_name       = \"${CLUSTER_NAME}\""
  echo "use_payload              = ${USE_PAYLOAD_FLAG}"
  echo "domain_name              = \"${DOMAIN_NAME}\""
  echo "domain_registered_in_aws = ${DOMAIN_IN_AWS}"
  echo "route53_zone_id          = \"${ROUTE53_ZONE_ID}\""

  if [[ "$USE_PAYLOAD_FLAG" == "true" ]]; then
    MONGODB_URI_ARN=$(get_ssm_arn "/clients/${CLIENT_NAME}/mongodb_uri")
    PAYLOAD_SECRET_ARN=$(get_ssm_arn "/clients/${CLIENT_NAME}/payload_secret")

    cat <<EOF
containers = [
  {
    name  = "payload"
    image = "payloadcms/payload:latest"
    port  = 3000
    secrets = {
      PAYLOAD_SECRET = "${PAYLOAD_SECRET_ARN}"
      MONGODB_URI    = "${MONGODB_URI_ARN}"
    }
    environment = {
      NODE_ENV = "production"
    }
  }
]
EOF
  fi
} > "$TFVARS_FILE"

echo "Finished. Wrote Terraform variables to: $TFVARS_FILE"
