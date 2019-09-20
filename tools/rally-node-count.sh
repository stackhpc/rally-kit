#!/bin/bash

# Wait for at least one baremetal node to become available.

set -e

OPENRC=${RALLY_NODE_COUNT_OPENRC:?Specify openrc file via \$RALLY_NODE_COUNT_OPENRC}
VENV=${RALLY_NODE_COUNT_VENV?Specify virtualenv via \$RALLY_NODE_COUNT_VENV}
RESOURCE_CLASS=${RALLY_NODE_COUNT_RESOURCE_CLASS:?Specify resource class via \$RALLY_NODE_COUNT_RESOURCE_CLASS}

source $OPENRC > /dev/null 2>&1
result=$($VENV/bin/openstack baremetal node list --resource-class $RESOURCE_CLASS --provision-state available --no-maintenance -f value --fields uuid | wc -l)
[ "$result" -ge 1 ]
