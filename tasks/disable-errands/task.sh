#!/bin/bash

set -eu

if [[ -z "$ERRANDS_TO_DISABLE" ]] || [[ "$ERRANDS_TO_DISABLE" == "none" ]]; then
  echo Nothing to do.
  exit 0
fi

enabled_errands=$(
  om-linux \
    --target "https://${OPSMAN_URI}" \
    --skip-ssl-validation \
    --username "$OPSMAN_USERNAME" \
    --password "$OPSMAN_PASSWORD" \
    errands \
    --product-name "$PRODUCT_NAME" |
  tail -n+4 | head -n-1 | grep -v false | cut -d'|' -f2 | tr -d ' '
)

if [[ "$ERRANDS_TO_DISABLE" == "all" ]]; then
  errands_to_disable="${enabled_errands[@]}"
else
  errands_to_disable=$(echo "$ERRANDS_TO_DISABLE" | tr ',' '\n')
fi

will_disable=$(
  echo $enabled_errands |
  jq \
    --arg to_disable "${errands_to_disable[@]}" \
    --raw-input \
    --raw-output \
    'split(" ")
    | reduce .[] as $errand ([];
       if $to_disable | contains($errand) then
         . + [$errand]
       else
         .
       end)
    | join("\n")'
)

if [ -z "$will_disable" ]; then
  echo Nothing to do.
  exit 0
fi

if [ ! -z "$WHEN_CHANGED" ]; then
  STATE="--post-deploy-state when-changed"
else
  STATE="--post-deploy-state disabled"
fi

while read errand; do
  echo -n Disabling $errand...
  om-linux \
    --target "https://${OPSMAN_URI}" \
    --skip-ssl-validation \
    --username "$OPSMAN_USERNAME" \
    --password "$OPSMAN_PASSWORD" \
    set-errand-state \
    --product-name "$PRODUCT_NAME" \
    --errand-name $errand \
    $STATE
#    --post-deploy-state "disabled"
  echo done
done < <(echo "$will_disable")
