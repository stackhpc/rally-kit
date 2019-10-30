# Rally Kit

This repo provides some tools and configuration for using Rally to test
hpcDIRECT.

## Rally installation

Install the dependencies:

```
yum install redhat-lsb-core gmp-devel libxml2-devel libxslt-devel postgresql-devel wget crudini
```

Install rally. Note that this should not be performed at the top level of a git
repository, or it will confuse the script.
```
wget -q -O- https://raw.githubusercontent.com/openstack/rally/master/install_rally.sh | bash
```

Modify the rally configuration to increase the client timeout to 300 seconds.
```
crudini --set ~/rally/etc/rally/rally.conf DEFAULT openstack_client_http_timeout 300
```


 ## Using rally

```
 . ~/rally/bin/activate
```

## Setting up rally

source an openstack environment file:

```
source kayobe/src/kayobe-config/etc/kolla/public-openrc.sh
```

You may need:

```
unset OS_CACERT
```

## Install openstack plugin

First activate the rally virtualenv and then:

```
pip install rally_openstack
```

## Create deployment

```
rally deployment create --fromenv --name test-environment
```

## Check a deployment

This serves as a good check to see if you have any obvious misconfiguration.

```
rally deployment check
```

## Setting up tempest

```
rally verify create-verifier --name tempest --type tempest
```

Optionally, use the `--source` and `--version` arguments to install tempest from
a downstream repo.

## Configuring tempest

A number of tempest configurations for different scenarios are provided under
the config/ directory.

For example, to use the VM fixed network configuration for the candidate
environment:

```
(rally) $ rally verify configure-verifier --reconfigure --extend config/candidate/vm-fixed-network.conf
```

## Running tempest

To run all tests:

```
rally verify start
```

### Generating a report

```
(rally) $ mkdir ~/rally-reports

(rally) $ rally verify report --type html --to ~/rally-reports/$(date -d "today" +"%Y%m%d%H%M").html
```

### Running individual tests

```
(rally) $ rally verify start --pattern tempest.api.compute.volumes.test_volume_snapshots.VolumesSnapshotsTestJSON.test_volume_snapshot_create_get_list_delete
```

### Rerunning failed tests
```
(rally) $ rally verify list
+--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+
| UUID                                 | Tags | Verifier name | Deployment name  | Started at          | Finished at         | Duration | Status   |
+--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+
| 3555945e-8799-403a-be19-bfdf1f72d936 | -    | tempest       | test-environment | 2019-07-12T15:53:07 | 2019-07-12T21:17:41 | 5:24:34  | failed   |
| da4a74ae-4a5d-4c47-88ce-7082ed8dd2c9 | -    | tempest       | test-environment | 2019-07-15T11:04:12 | 2019-07-15T11:05:04 | 0:00:52  | failed   |
| aa8d325c-be1c-4938-86e9-a49c246dda00 | -    | tempest       | test-environment | 2019-07-15T11:19:14 | 2019-07-15T11:39:43 | 0:20:29  | failed   |
| 5ac158fa-ef6f-46ac-b091-fe1ec444d3c8 | -    | tempest       | test-environment | 2019-07-15T13:23:39 | 2019-07-15T13:24:28 | 0:00:49  | finished |
+--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+

(rally) $ rally verify rerun --failed --uuid 3555945e-8799-403a-be19-bfdf1f72d936
```

## Test Configurations

Tempest overrides for different test configurations can be generated with the config generator.

### Installing the config generator

Change to the config generator directory:

```
cd config_gen
```

#### Set up a virtual environment

##### python 3

```
python -m venv venv
source venv/bin/activate
pip install requirements.txt
```

##### python 2:

```
virtualenv venv
source venv/bin/activate
pip install requirements.txt
```

### Download the recipes for your deployment

git clone https://github.com/stackhpc/tempest-recipes.git recipes

### Generate config files

ansible-playbook template.yml -e@recipes/candidate/baremetal-fix-ip.yml

where `candidate/baremetal-fix-ip.yml` is a path in the recipes repository.

### Run tempest

Check the recipes repository for a README explaining how to run tempest with
that config.

## Background: Generating lists of bare metal tests

### Creating a list of tests that don't need compute

Rationale: we want to speed up tempest runs, but booting baremetal servers must be
done serially. If we split the tests into two groups, we can run the group that 
doesn't boot any servers with --concurrency > 1.

Run the tempest smoke tests with the compute service disabled, e.g in tempest.conf:

```
[service_available]
nova = false
```

you must also start the run with the
`blacklists/helpers/tempest-no-compute-blacklist` blacklist.  This contains a
series of regexps that should prevent any tests that use the compute service
from running.

The rally invocation will look like:

```
rally verify start --skip-list blacklists/helpers/tempest-no-compute-blacklist
```

Grab the list of tests from that run:

```
./tools/tempest-tests-in-report.sh --uuid 06597b42-015b-4629-8ae5-14dfddf08f18 | ./tools/tempest-tests-to-blacklist > /tmp/no-compute
```

expand regexps:

```
python tools/tempest-blacklist.py /tmp/no-compute > blacklists/helpers/no-compute
```

This will be used as the `--skip-list` in the second run of rally.

### Create skip list for bare metal fixed network tests

Concatenate a bunch of blacklists together:
```
cat blacklists/helpers/{no-compute,site,tempest-ironic-blacklist} > /tmp/skip_list
```

expand regexps:

```
python tools/tempest-blacklist.py /tmp/skip_list > blacklists/bare-metal-fixed-network
```

### Making sure the test set doesn't change with tempest version

You can use `tools/tempest-tests-in-report.sh` to generate a `--load-list`.
This means that you will run the same of set of tests even across tempest
upgrades (where new tests may be added).  It is recommended that you do this
for:

- the tests run without the compute service enabled
- the tests run with the compute service enabled

This way it will be easier to compare results.
