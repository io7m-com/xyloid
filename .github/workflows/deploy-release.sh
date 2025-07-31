#!/bin/sh

#------------------------------------------------------------------------
# Utility methods
#

fatal()
{
  echo "deploy-release.sh: fatal: $1" 1>&2
  exit 1
}

info()
{
  echo "deploy-release.sh: info: $1" 1>&2
}

error()
{
  echo "deploy-release.sh: error: $1" 1>&2
}

#------------------------------------------------------------------------
# Check environment
#

FAILED=0
if [ -z "${MAVEN_CENTRAL_USERNAME}" ]
then
  error "MAVEN_CENTRAL_USERNAME is not defined"
  FAILED=1
fi
if [ -z "${MAVEN_CENTRAL_PASSWORD}" ]
then
  error "MAVEN_CENTRAL_PASSWORD is not defined"
  FAILED=1
fi

if [ ${FAILED} -eq 1 ]
then
  fatal "One or more required variables are not defined."
fi

#------------------------------------------------------------------------
# Check the built artifacts.
#

START_DIRECTORY="$(pwd)"
DEPLOY_DIRECTORY="$(pwd)/build/maven"

info "The following artifacts will be deployed:"
find "${DEPLOY_DIRECTORY}" -type f

info "Signing artifacts..."
find "${DEPLOY_DIRECTORY}" -type f -exec gpg -a --sign --detach-sign {} \; ||
  fatal "Could not sign artifacts."

info "Produced signatures:"
find "${DEPLOY_DIRECTORY}" -type f -name '*.asc' ||
  fatal "Could not list signatures."

info "Checking signatures were created"
SIGNATURE_COUNT=$(find "${DEPLOY_DIRECTORY}" -type f -name '*.asc' | wc -l) || fatal "Could not list signatures"
info "Generated ${SIGNATURE_COUNT} signatures"
if [ "${SIGNATURE_COUNT}" -lt 2 ]
then
  fatal "Too few signatures were produced! check the PGP setup!"
fi

#------------------------------------------------------------------------
# Create a bundle to be uploaded
#

cd "${DEPLOY_DIRECTORY}" ||
  fatal "Could not switch directories."
zip -9 -r "${START_DIRECTORY}/bundle.zip" . ||
  fatal "Could not generate bundle."
cd "${START_DIRECTORY}" ||
  fatal "Could not switch directories."

#------------------------------------------------------------------------
# Upload bundle.
#

BEARER_TOKEN=$(echo "${MAVEN_CENTRAL_USERNAME}:${MAVEN_CENTRAL_PASSWORD}" | base64)

info "Uploading bundle..."
DEPLOYMENT_ID=$(
  curl \
    --request POST \
    --verbose \
    --header "Authorization: Bearer ${BEARER_TOKEN}" \
    --form bundle=@bundle.zip \
    "https://central.sonatype.com/api/v1/publisher/upload?publishingType=AUTOMATIC"
) || fatal "Could not upload bundle."

while true
do
  info "Checking deployment state..."

  DEPLOYMENT_STATE=$(
  curl \
    --request POST \
    --verbose \
    --header "Authorization: Bearer ${BEARER_TOKEN}" \
    "https://central.sonatype.com/api/v1/publisher/status?id=${DEPLOYMENT_ID}" \
    | jq -r ".deploymentState"
  ) || fatal "Could not check deployment state."

  info "Deployment state: ${DEPLOYMENT_STATE}"
  if [ "${DEPLOYMENT_STATE}" = "PUBLISHED" ]
  then
    info "Deployed"
    exit 0
  fi
  if [ "${DEPLOYMENT_STATE}" = "FAILED" ]
  then
    fatal "Failed!"
  fi

  sleep 10
done