#!/bin/bash -ex

#mv tool-om/om-linux-* tool-om/om-linux
chmod +x tool-om/om-linux
CMD=./tool-om/om-linux

RELEASE=`$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep pas-windows`

PRODUCT_NAME=`echo $RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $RELEASE | cut -d"|" -f3 | tr -d " "`

PRODUCT_PROPERTIES=$(cat <<-EOF
{
  ".properties.windows_admin_password": {
    "value": "$WIN_ADMIN_PASSWD"
  },
  ".properties.kms": {
    "value": "$KMS"
  },
  ".properties.system_logging": {
    "value": "$SYSLOG_ENABLED"
  },
  ".properties.system_logging.enable.syslog_host": {
    "value": "$SYSLOG_HOST"
  },
  ".properties.system_logging.enable.syslog_port": {
    "value": $SYSLOG_PORT
  },
  ".properties.system_logging.enable.syslog_protocol": {
    "value": "$SYSLOG_PROTOCOL"
  },
  ".properties.bosh_ssh_enabled": {
    "value": "$SSH_ENABLED"
  },
  ".properties.rdp_enabled": {
    "value": "$RDP_ENABLED"
  }
}
EOF
)

function fn_other_azs {
  local azs_csv=$1
  echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

OTHER_AZS=$(fn_other_azs $DEPLOYMENT_NW_AZS)

PRODUCT_NETWORK_CONFIG=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$SINGLETON_JOB_AZ"
  },
  "other_availability_zones": [
    $OTHER_AZS
  ],
  "network": {
    "name": "$NETWORK_NAME"
  }
}
EOF
)

PRODUCT_RESOURCE_CONFIG=$(cat <<-EOF
{
  "windows_diego_cell": {
    "instance_type": {"id": "$WIN_CELL_TYPE"},
    "instances" : $WIN_CELL_COUNT
  }
}
EOF
)

$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PRODUCT_PROPERTIES" -pn "$PRODUCT_NETWORK_CONFIG" -pr "$PRODUCT_RESOURCE_CONFIG"

