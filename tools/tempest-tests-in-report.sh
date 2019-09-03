#!/bin/bash
# Usage: ./tempest-tests-in-report --uuid myuuid 

scratch=$(mktemp)

function finish {
  rm -rf "$scratch"
}
trap finish EXIT

rally verify report --type json --to $scratch $@ >/dev/null 2>&1; cat $scratch | jq -r '.tests | to_entries[] | select(.value.by_verification[].status == "success") | "\(.key)"'
