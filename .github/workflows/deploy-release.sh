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
if [ -z "${MAVEN_CENTRAL_STAGING_PROFILE_ID}" ]
then
  error "MAVEN_CENTRAL_STAGING_PROFILE_ID is not defined"
  FAILED=1
fi

if [ ${FAILED} -eq 1 ]
then
  fatal "One or more required variables are not defined."
fi

#------------------------------------------------------------------------
# Download Brooklime if necessary.
#

BROOKLIME_URL="https://repo1.maven.org/maven2/com/io7m/brooklime/com.io7m.brooklime.cmdline/2.0.1/com.io7m.brooklime.cmdline-2.0.1-main.jar"
BROOKLIME_SHA256_EXPECTED="eb77e7459f3ece239f68e0b634be6cf9f8b57d6c18f0a2bce1cd6a06c611a3ff"

wget -O "brooklime.jar.tmp" "${BROOKLIME_URL}" || fatal "Could not download brooklime"
mv "brooklime.jar.tmp" "brooklime.jar" || fatal "Could not rename brooklime"

BROOKLIME_SHA256_RECEIVED=$(openssl sha256 "brooklime.jar" | awk '{print $NF}') || fatal "Could not checksum brooklime.jar"

if [ "${BROOKLIME_SHA256_EXPECTED}" != "${BROOKLIME_SHA256_RECEIVED}" ]
then
  fatal "brooklime.jar checksum does not match.
  Expected: ${BROOKLIME_SHA256_EXPECTED}
  Received: ${BROOKLIME_SHA256_RECEIVED}"
fi

#------------------------------------------------------------------------
# Check the built artifacts.
#

DEPLOY_DIRECTORY="$(pwd)/build/maven"
info "Artifacts will temporarily be deployed to ${DEPLOY_DIRECTORY}"

find "${DEPLOY_DIRECTORY}" -type f -exec gpg --sign --detach-sign {} \; ||
  fatal "Could not sign artifacts."

info "Checking signatures were created"
SIGNATURE_COUNT=$(find "${DEPLOY_DIRECTORY}" -type f -name '*.asc' | wc -l) || fatal "Could not list signatures"
info "Generated ${SIGNATURE_COUNT} signatures"
if [ "${SIGNATURE_COUNT}" -lt 2 ]
then
  fatal "Too few signatures were produced! check the PGP setup!"
fi

#------------------------------------------------------------------------
# Create a staging repository on Maven Central.
#

info "Creating a staging repository on Maven Central"

(cat <<EOF
create
--baseURI
https://s01.oss.sonatype.org/
--description
ThePalaceProject ${TIMESTAMP}
--stagingProfileId
${MAVEN_CENTRAL_STAGING_PROFILE_ID}
--user
${MAVEN_CENTRAL_USERNAME}
--password
${MAVEN_CENTRAL_PASSWORD}
EOF
) > args.txt || fatal "Could not write argument file"

MAVEN_CENTRAL_STAGING_REPOSITORY_ID=$(java -jar brooklime.jar @args.txt) || fatal "Could not create staging repository"

#------------------------------------------------------------------------
# Upload content to the staging repository on Maven Central.
#

info "Uploading content to repository ${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}"

(cat <<EOF
upload
--verbose
debug
--baseURI
https://s01.oss.sonatype.org/
--stagingProfileId
${MAVEN_CENTRAL_STAGING_PROFILE_ID}
--user
${MAVEN_CENTRAL_USERNAME}
--password
${MAVEN_CENTRAL_PASSWORD}
--directory
${DEPLOY_DIRECTORY}
--repository
${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}
--quiet
EOF
) > args.txt || fatal "Could not write argument file"

java -jar brooklime.jar @args.txt || fatal "Could not upload content"

#------------------------------------------------------------------------
# Close the staging repository.
#

info "Closing repository ${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}. This can take a few minutes."

(cat <<EOF
close
--baseURI
https://s01.oss.sonatype.org/
--stagingProfileId
${MAVEN_CENTRAL_STAGING_PROFILE_ID}
--user
${MAVEN_CENTRAL_USERNAME}
--password
${MAVEN_CENTRAL_PASSWORD}
--repository
${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}
EOF
) > args.txt || fatal "Could not write argument file"

java -jar brooklime.jar @args.txt || fatal "Could not close staging repository"

#------------------------------------------------------------------------
# Release the staging repository.
#

info "Releasing repository ${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}"

(cat <<EOF
release
--baseURI
https://s01.oss.sonatype.org/
--stagingProfileId
${MAVEN_CENTRAL_STAGING_PROFILE_ID}
--user
${MAVEN_CENTRAL_USERNAME}
--password
${MAVEN_CENTRAL_PASSWORD}
--repository
${MAVEN_CENTRAL_STAGING_REPOSITORY_ID}
EOF
) > args.txt || fatal "Could not write argument file"

java -jar brooklime.jar @args.txt || fatal "Could not release staging repository"

info "Release completed"
