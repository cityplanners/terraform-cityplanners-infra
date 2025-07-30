#!/bin/bash

REGION="us-east-1"

read -sp "Enter MongoDB Atlas public key: " MONGODB_PUBLIC_KEY
echo ""

aws ssm put-parameter \
  --name "/global/mongodb_atlas_public_key" \
  --type "SecureString" \
  --value "${MONGODB_PUBLIC_KEY}" \
  --overwrite \
  --region "$REGION"

read -sp "Enter MongoDB Atlas private key: " MONGODB_PRIVATE_KEY
echo ""

aws ssm put-parameter \
  --name "/global/mongodb_atlas_private_key" \
  --type "SecureString" \
  --value "${MONGODB_PRIVATE_KEY}" \
  --overwrite \
  --region "$REGION"

read -sp "Enter MongoDB Atlas project ID: " MONGODB_PROJECT_ID
echo ""

aws ssm put-parameter \
  --name "/global/mongodb_atlas_project_id" \
  --type "SecureString" \
  --value "${MONGODB_PROJECT_ID}" \
  --overwrite \
  --region "$REGION"

echo "✅ Global secrets stored securely in SSM Parameter Store."
