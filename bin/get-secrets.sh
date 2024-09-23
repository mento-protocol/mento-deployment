#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

##############################################################################
# Script for pulling secret keys from GCP secret manager.
# Usage: ./bin/get-secrets.sh
##############################################################################

# Authenticate with Google Cloud
# gcloud auth login

# Set the project ID and the comma-separated list of secret IDs to retrieve
PROJECT_ID="mento-prod"
SECRET_IDS="mento-deployer-pk,baklava-approver-pk,baklava-voter-pk,dune-api-key"

# Set the path to the .env file as the parent directory of the current directory
ENV_FILE="$(dirname "$0")/../.env"
ENV_EXAMPLE_FILE="$(dirname "$0")/../.env.example"

# Check if .env file exists, if not, copy .env.example to .env
if [[ ! -f ${ENV_FILE} ]]; then
	if [[ -f ${ENV_EXAMPLE_FILE} ]]; then
		echo "Didn't find .env file. Copying .env.example to .env..."
		cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
		echo "✅ .env file created from .env.example"
	else
		echo "❌ Error: .env.example file not found. Cannot create .env file."
		exit 1
	fi
fi

# Loop through the comma-separated list of secret IDs and retrieve the secret values
for SECRET_ID in $(echo "${SECRET_IDS}" | tr ',' ' '); do
	# Step 1: Retrieve the secret value from Google Cloud
	SECRET_NAME="$(echo "${SECRET_ID}" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"

	printf "\nRetrieving secret %s..." "${SECRET_NAME}"
	SECRET_VALUE="$(gcloud secrets versions access latest --secret="${SECRET_ID}" --project="${PROJECT_ID}")"
	printf "✅\n"

	# Step 2: Write the secret value to the .env file
	if grep -q "^${SECRET_NAME}=" "${ENV_FILE}"; then
		# Step 2a: If the secret name already exists in the .env file, replace the value with the new value.
		printf "Replacing secret %s in .env..." "${SECRET_NAME}"
		if [[ ${OSTYPE} == "darwin"* ]]; then
			# macOS sed syntax
			sed -i "" "s/^${SECRET_NAME}=.*/${SECRET_NAME}=${SECRET_VALUE}/g" "${ENV_FILE}"
		else
			# GNU/Linux sed syntax
			sed -i "s/^${SECRET_NAME}=.*/${SECRET_NAME}=${SECRET_VALUE}/g" "${ENV_FILE}"
		fi
		printf "✅\n"
	else
		# Step 2b: If the .env file is not empty, append the secret name and value to the .env file.
		printf "Writing secret %s to .env file..." "${SECRET_NAME}"
		if [[ -s ${ENV_FILE} ]]; then
			printf "\n%s=%s" "${SECRET_NAME}" "${SECRET_VALUE}" >>"${ENV_FILE}"
		else
			# If we don't have an .env, write the secret name and value to the .env file.
			echo -n "${SECRET_NAME}=${SECRET_VALUE}" >>"${ENV_FILE}"
		fi
		printf "✅\n"
	fi
done
