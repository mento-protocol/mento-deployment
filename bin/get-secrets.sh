#!/bin/bash

##############################################################################
# Script for pulling secret keys from GCP secret manager.
# Usage: ./bin/get-secrets.sh 
##############################################################################

# Authenticate with Google Cloud
# gcloud auth login

# Set the project ID and the comma-separated list of secret IDs to retrieve
PROJECT_ID="mento-prod"
SECRET_IDS="mento-deployer-pk,baklava-approver-pk,baklava-voter-pk"

# Set the path to the .env file as the parent directory of the current directory
ENV_FILE="$( dirname -- "$0"; )/../.env"
echo $ENV_FILE

# Loop through the comma-separated list of secret IDs and retrieve the secret values
for SECRET_ID in $(echo "$SECRET_IDS" | tr ',' ' '); do
  # Retrieve the secret value from Google Cloud
  SECRET_NAME="$(echo "$SECRET_ID" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
  SECRET_VALUE="$(gcloud secrets versions access latest --secret="$SECRET_ID" --project="$PROJECT_ID")"

  # Write the secret value to the .env file
  
  # If the secret name already exists in the .env file, replace the value with the new value. 
  if grep -q "^$SECRET_NAME=" "$ENV_FILE"; then
    sed -i "s/^$SECRET_NAME=.*/$SECRET_NAME=$SECRET_VALUE/g" "$ENV_FILE"
  else
    # If the .env file is not empty, append the secret name and value to the .env file.
    if [[ -s "$ENV_FILE" ]]; then
      printf "\n%s=%s" "$SECRET_NAME" "$SECRET_VALUE" >> "$ENV_FILE"
    else
      # If we don't have an .env, write the secret name and value to the .env file.
      echo -n "$SECRET_NAME=$SECRET_VALUE" >> "$ENV_FILE"
    fi
  fi
done