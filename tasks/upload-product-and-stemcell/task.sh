#!/bin/bash

set -eu

if [[ -n "$NO_PROXY" ]]; then
  echo "$OM_IP $OPS_MGR_HOST" >> /etc/hosts
fi

chmod +x tool-om/om-linux
CMD=`pwd`/tool-om/om-linux

STEMCELL_VERSION=$(
  cat ./pivnet-product/metadata.json |
  jq --raw-output \
    '
    [
      .Dependencies[]
      | select(.Release.Product.Name | contains("Stemcells"))
      | .Release.Version
    ] | sort | last // empty
    '
)

if [ -n "$STEMCELL_VERSION" ]; then
  diagnostic_report=$(
    $CMD \
      --target https://$OPS_MGR_HOST \
      --username $OPS_MGR_USR \
      --password $OPS_MGR_PWD \
      --skip-ssl-validation \
      curl --silent --path "/api/v0/diagnostic_report"
  )

  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )

  if [[ -z "$stemcell" ]]; then
    echo "Downloading stemcell $STEMCELL_VERSION"
    if [[ "$PASWINDOWS" = "true" ]]; then
       echo "S3 download of $STEMCELL_VERSION"
    else
       pivnet-cli login --api-token="$PIVNET_API_TOKEN"
       pivnet-cli download-product-files -p stemcells -r $STEMCELL_VERSION -g "*${IAAS}*" --accept-eula
    fi

    SC_FILE_PATH=`find ./ -name *.tgz`

    if [ ! -f "$SC_FILE_PATH" ]; then
      echo "Stemcell file not found!"
      exit 1
    fi

    $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH
  fi
fi

FILE_PATH=`find ./pivnet-product -name *.pivotal`
if [[ "$PASWINDOWS" = "true" ]]; then
   cd pivnet-product
   unzip winfs-injector*.zip winfs-injector-linux
   chmod 755 winfs-injector-linux
   ./winfs-injector-linux --input-tile *.pivotal --output-tile pas-windows-injected.pivotal
   $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k --request-timeout 3600 upload-product -p pas-windows-injected.pivotal
else
   $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k --request-timeout 3600 upload-product -p $FILE_PATH
fi

#
# Sleep for a while in case the problems with not staging we are seeing are because the upload hasn't really finished
#
sleep 20
