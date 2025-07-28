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

  # Prompt for and create MongoDB password secret
  read -sp "Enter MongoDB DB password for $CLIENT_NAME: " DB_PASS
  echo ""

  aws secretsmanager create-secret \
    --name /clients/${CLIENT_NAME}/mongodb-password \
    --description "MongoDB password for Payload CMS for $CLIENT_NAME" \
    --secret-string "{\"password\":\"${DB_PASS}\"}" \
    --region $REGION

  # Construct and store the MongoDB URI
  MONGODB_URI="mongodb+srv://payload-${CLIENT_NAME}:${DB_PASS}@${CLUSTER_NAME}.mongodb.net/${CLIENT_NAME}"

  aws secretsmanager create-secret \
    --name /clients/${CLIENT_NAME}/mongodb_uri \
    --secret-string "${MONGODB_URI}" \
    --description "MongoDB connection string for Payload CMS for ${CLIENT_NAME}" \
    --region $REGION

  # Prompt for and create Payload secret
  read -sp "Enter Payload secret for $CLIENT_NAME: " PAYLOAD_SECRET
  echo ""

  aws secretsmanager create-secret \
    --name /clients/${CLIENT_NAME}/payload_secret \
    --secret-string "${PAYLOAD_SECRET}" \
    --region $REGION
fi

# Fetch ARNs for generated secrets
get_secret_arn() {
  local name="$1"
  aws secretsmanager list-secrets \
    --region "$REGION" \
    --no-paginate \
    --query "SecretList[?Name=='${name}'].ARN | [0]" \
    --output text
}

read -p "Enter custom domain name for ${CLIENT_NAME}: " DOMAIN_NAME

read -p "Is the domain registered in AWS Route 53? (y/n): " USE_AWS_DOMAIN
if [[ "$USE_AWS_DOMAIN" == "y" || "$USE_AWS_DOMAIN" == "Y" ]]; then
  DOMAIN_IN_AWS=true
  read -p "Enter Route 53 Hosted Zone ID: " ROUTE53_ZONE_ID
else
  DOMAIN_IN_AWS=false
  ROUTE53_ZONE_ID=""
fi

# Start writing the tfvars
TFVARS_FILE="clients/${CLIENT_NAME}.tfvars"
{
  echo "project_name = \"${CLIENT_NAME}\""
  echo "use_payload  = ${USE_PAYLOAD_FLAG}"
  echo "domain_name              = \"${DOMAIN_NAME}\""
  echo "domain_registered_in_aws = ${DOMAIN_IN_AWS}"
  echo "route53_zone_id          = \"${ROUTE53_ZONE_ID}\""

  if [[ "$USE_PAYLOAD_FLAG" == "true" ]]; then
    MONGODB_URI_ARN=$(get_secret_arn "/clients/${CLIENT_NAME}/mongodb_uri")
    PAYLOAD_SECRET_ARN=$(get_secret_arn "/clients/${CLIENT_NAME}/payload_secret")

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

echo "✅ Finished. Wrote Terraform variables to: $TFVARS_FILE"
