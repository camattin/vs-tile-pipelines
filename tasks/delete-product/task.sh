#!/bin/bash -e

set -x

#mv tool-om/om-linux-* tool-om/om-linux
chmod +x tool-om/om-linux
CMD=./tool-om/om-linux

RELEASE=`$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep $PRODUCT`

if [ $? -ne 0 ]; then
   echo "Specified product $PRODUCT does not exist in this foundation."
   exit 1
fi

PRODUCT_VERSION=`echo $RELEASE | cut -d"|" -f3 | tr -d " "`

if [ $PRODUCT_VERSION = "" ]; then
   echo "Unable to determine product version!"
   exit 1
fi

echo "Unstaging product..."
$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k unstage-product -p $PRODUCT

echo "Deleting all unused products..."
$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k delete-product -p $PRODUCT -v $PRODUCT_VERSION

echo "Done"
