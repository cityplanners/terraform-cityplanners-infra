#!/bin/bash

read -sp "Enter MongoDB Atlas public key: " MONGODB_PUBLIC_KEY
echo ""

aws secretsmanager create-secret \
                      --name /global/mongodb_atlas_public_key \
                      --secret-string "${MONGODB_PUBLIC_KEY}"

read -sp "Enter MongoDB Atlas private key: " MONGODB_PRIVATE_KEY
echo ""

aws secretsmanager create-secret \
                      --name /global/mongodb_atlas_private_key \
                      --secret-string "${MONGODB_PRIVATE_KEY}"

read -sp "Enter MongoDB Atlas project id: " MONGODB_PROJECT_ID
echo ""

aws secretsmanager create-secret \
                      --name /global/mongodb_atlas_project_id \
                      --secret-string "${MONGODB_PROJECT_ID}"
