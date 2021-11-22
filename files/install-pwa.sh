#!/usr/bin/env bash

set -eu

# Move execution to realpath of script
cd $(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

########################################
## Command Line Options
########################################
declare CONFIG_FILE=""
for switch in $@; do
    case $switch in
        *)
            CONFIG_FILE="${switch}"
            if [[ "${CONFIG_FILE}" =~ ^.+$ ]]; then
              if [[ ! -f "${CONFIG_FILE}" ]]; then
                >&2 echo "Error: Invalid config file given"
                exit -1
              fi
            fi
            ;;
    esac
done
if [[ $# < 1 ]]; then
  echo "An argument was not specified:"
  echo " <config_filename>    Specify config file to use to override default configs."
  echo ""
  echo "Exampe: install-pwa.sh config_site.json"
  exit;
fi

# Config Files
CONFIG_DEFAULT="config_default.json"
CONFIG_OVERRIDE="${CONFIG_FILE}"
[[ "${CONFIG_OVERRIDE}" != "" && -f ${CONFIG_OVERRIDE} ]] || CONFIG_OVERRIDE=""

# Read merged config JSON files
declare CONFIG_NAME=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.CONFIG_NAME')
declare SITE_HOSTNAME=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.SITE_HOSTNAME')

declare MAGENTO_ROOT_DIR=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.MAGENTO_ROOT_DIR')
declare ENV_ROOT_DIR=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.ENV_ROOT_DIR')
declare PWA_STUDIO_VERSION=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.PWA_STUDIO_VERSION')
declare PWA_STUDIO_COMPAT_MATRIX_URL=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.PWA_STUDIO_COMPAT_MATRIX_URL')
declare PWA_STUDIO_DOWNLOAD_URL=$(cat ${CONFIG_DEFAULT} ${CONFIG_OVERRIDE} | jq -s add | jq -r '.PWA_STUDIO_DOWNLOAD_URL')

# Checking Magento and PWA Studio version compability
echo "----: Checking Magento and PWA Studio versions compability"
declare -i IS_COMPAT=0

cd ${MAGENTO_ROOT_DIR}
MAGENTO_REL_VER=$(grep version composer.json |head -n1 |awk -F "\"" {' print $4 '})
# removing patch releases
MAGENTO_MAIN_VER=$(echo ${MAGENTO_REL_VER} | sed 's/-p.$//')

# Get compability matrix
IS_COMPAT=$(curl -Ls ${PWA_STUDIO_COMPAT_MATRIX_URL} |awk -F "'" {' print $2":"$4 '} |grep -v '^:$' | while read line; do

PWA_COMPAT_VER=`echo $line |awk -F ":" {' print $1 '}`
MAGENTO_COMPAT_VER=`echo $line |awk -F ":" {' print $2 '} |sed 's/ - / /'`

if [[ ${MAGENTO_COMPAT_VER} =~ ${MAGENTO_MAIN_VER} ]]; then
  if [[ ${PWA_COMPAT_VER} == ${PWA_STUDIO_VERSION} ]]; then
     IS_COMPAT=$((IS_COMPAT + 1)) && echo ${IS_COMPAT}
  fi
fi
done)

if (( ${IS_COMPAT} >=  1 )); then
     echo "----: The versions of Magento and PWA Studio are compatible:

      Magento version: ${MAGENTO_REL_VER}
      PWA Studio: ${PWA_STUDIO_VERSION}"

else
     echo "Please check Magento and PWA Studio version compability:

      Magento version: ${MAGENTO_REL_VER}
      PWA Studio: ${PWA_STUDIO_VERSION}

      Compability matrix: https://magento.github.io/pwa-studio/technologies/magento-compatibility/"
     exit 1;
fi

  echo "----: Preparing PWA code"
  mkdir ${ENV_ROOT_DIR}/pwa-studio && cd ${ENV_ROOT_DIR}/pwa-studio

  curl -L -s ${PWA_STUDIO_DOWNLOAD_URL}v${PWA_STUDIO_VERSION}.tar.gz -o ${PWA_STUDIO_VERSION}.tar.gz
  tar xf ${PWA_STUDIO_VERSION}.tar.gz --strip-components 1 && rm ${PWA_STUDIO_VERSION}.tar.gz

  # Generate Braintree Token
  declare BTOKEN=sandbox_$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 8 | head -n1)_$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 16 | head -n1)

  echo "----: Run buildpack"
  echo y | npx @magento/pwa-buildpack create-project pwa --name PWA --author PWADemo --template "@magento/venia-concept" --backend-url "https://${SITE_HOSTNAME}" --braintree-token "${BTOKEN}" --npm-client "yarn"

  mv pwa ${MAGENTO_ROOT_DIR}/ && cd ${MAGENTO_ROOT_DIR}

  echo "----: Checking Magento license"

  declare MAGENTO_COMPOSER_PROJECT=$(grep 'magento/product-' composer.json |awk -F "\"" {' print $2 '} |awk -F "-" {' print $2 '})
  if [[ ${MAGENTO_COMPOSER_PROJECT} =~ "enterprise" ]]; then
    sed -i 's/MAGENTO_BACKEND_EDITION=CE/MAGENTO_BACKEND_EDITION=EE/' pwa/.env
  fi

  echo "----: Yarn build"
  cd pwa && yarn build

  echo "----: Installing magento/module-upward-connector"
  cd ${MAGENTO_ROOT_DIR}
  composer require magento/module-upward-connector
  bin/magento module:enable Magento_UpwardConnector
  bin/magento setup:upgrade
  bin/magento config:set web/upward/path "${PWD}/pwa/dist/upward.yml"
  bin/magento setup:di:compile
  bin/magento setup:static-content:deploy -f
  bin/magento cache:flush

echo "----: PWA Install Finished"
