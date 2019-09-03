#!/bin/bash
# Usage: ./tempest-tests-in-report.sh | ./tempest-tests-to-blacklist.sh
while read line
do
  echo "$line: passed in a previous run"
done < "${1:-/dev/stdin}"
