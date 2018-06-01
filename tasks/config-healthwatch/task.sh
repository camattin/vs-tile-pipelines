#!/bin/bash -e

set -x

#mv tool-om/om-linux-* tool-om/om-linux
chmod +x tool-om/om-linux
CMD=./tool-om/om-linux

RELEASE=`$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep $PRODUCT_NAME`

PRODUCT_NAME=`echo $RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $RELEASE | cut -d"|" -f3 | tr -d " "`

$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

function fn_other_azs {
  local azs_csv=$1
  echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

OTHER_AZS=$(fn_other_azs $OTHER_JOB_AZS)

NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$SINGLETON_JOB_AZ"
  },
  "other_availability_zones": [
    $OTHER_AZS
  ],
  "network": {
    "name": "$DEPLOYMENT_NETWORK_NAME"
  },
  "service_network": {
    "name": "$NETWORK_NAME"
  }
}
EOF
)

if [ ! -z $OPSMAN_URI ]; then
  opsman_uri="https://${OPSMAN_URI}"
else
  opsman_uri=""
fi

PROPERTIES=$(cat <<-EOF
{
    ".properties.opsman.enable.url": {
      "value": "$opsman_uri"
    },
    ".healthwatch-forwarder.health_check_az": {
      "value": "$SINGLETON_JOB_AZ"
    },
    ".healthwatch-forwarder.bosh_taskcheck_username": {
      "value": "$UAA_USERNAME"
    },
    ".healthwatch-forwarder.bosh_taskcheck_password": {
      "value": "$UAA_PASSWORD"
    }
}
EOF
)

RESOURCES=$(cat <<-EOF
{
}
EOF
)

$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PROPERTIES" -pn "$NETWORK" -pr "$RESOURCES"
