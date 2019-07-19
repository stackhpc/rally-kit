===========
Cheat sheet
===========

Rally installation
==================

install the dependencies:

.. code-block:: shell
  yum install redhat-lsb-core gmp-devel libxml2-devel libxslt-devel postgresql-devel

install rally

.. code-block:: shell
  wget -q -O- https://raw.githubusercontent.com/openstack/rally/master/install_rally.sh | bash


Using rally
===========

.. code-block:: shell
 . /home/stackhpc/rally/bin/activate

Setting up rally
================

source and openstack environment file:

.. code-block:: shell
  source kayobe/src/kayobe-config/etc/kolla/public-openrc.sh

You may need:

.. code-block:: shell
  unset OS_CACERT

Install openstack plugin
========================

Activate the rally virtualenv and then:

.. code-block:: shell
 pip install rally_openstack

Create deployment
=================

.. code-block:: shell
  rally deployment create --fromenv --name test-environment


Check a deployment
==================

This serves as a good check to see if you have any obvious misconfiguration.

.. code-block:: shell
  rally deployment check

Setting up tempest
==================

.. code-block:: shell
  rally verify create-verifier --name tempest --type tempest

Running tempest
===============

.. code-block:: shell
  rally verify start

Generating a report
===================

.. code-block:: shell
  (rally) [stackhpc@bm-test-mgmt01 ~]$ mkdir ~/rally-reports

  (rally) [stackhpc@bm-test-mgmt01 ~]$ rally verify report --type html --to ~/rally-reports/$(date -d "today" +"%Y%m%d%H%M").html

Reconfiguring tempest
=====================

Example: increase volume timeouts

.. code-block:: shell
  (rally) [stackhpc@bm-test-mgmt01 rally-config]$ cat ~/rally-config/tempest-override.conf
  [volume]
  build_timeout = 600

.. code-block:: shell
 (rally) [stackhpc@bm-test-mgmt01 rally-config]$ rally verify configure-verifier --reconfigure --extend ~/rally-config/tempest-override.conf

Known good configs
------------------

These are specific to each site and can be found in the configs subdirectory. The can be 
used as a basis for another site but UUIDs specific to each environment must be removed.

Running individual tests
==============================

.. code-block:: shell
 rally verify start --pattern tempest.api.compute.volumes.test_volume_snapshots.VolumesSnapshotsTestJSON.test_volume_snapshot_create_get_list_delete

Rerunning failed tests
======================
.. code-block:: shell
 (rally) [stackhpc@bm-test-mgmt01 rally-config]$ rally verify list
 +--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+
 | UUID                                 | Tags | Verifier name | Deployment name  | Started at          | Finished at         | Duration | Status   |
 +--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+
 | 3555945e-8799-403a-be19-bfdf1f72d936 | -    | tempest       | test-environment | 2019-07-12T15:53:07 | 2019-07-12T21:17:41 | 5:24:34  | failed   |
 | da4a74ae-4a5d-4c47-88ce-7082ed8dd2c9 | -    | tempest       | test-environment | 2019-07-15T11:04:12 | 2019-07-15T11:05:04 | 0:00:52  | failed   |
 | aa8d325c-be1c-4938-86e9-a49c246dda00 | -    | tempest       | test-environment | 2019-07-15T11:19:14 | 2019-07-15T11:39:43 | 0:20:29  | failed   |
 | 5ac158fa-ef6f-46ac-b091-fe1ec444d3c8 | -    | tempest       | test-environment | 2019-07-15T13:23:39 | 2019-07-15T13:24:28 | 0:00:49  | finished |
 +--------------------------------------+------+---------------+------------------+---------------------+---------------------+----------+----------+

 (rally) [stackhpc@bm-test-mgmt01 rally-config]$ rally verify rerun --failed --uuid 3555945e-8799-403a-be19-bfdf1f72d936

Baremetal tests
===============

Creating a list of tests that don't need compute
------------------------------------------------

Rationale: we want to speed up tempest runs, but booting baremetal servers must be
done serially. If we split the tests into two groups, we can run the group that 
doesn't boot any servers with --concurrency > 1.

Run the tempest smoke tests with the compute service disabled, e.g in tempest.conf:

.. code-block:: shell
 [service_available]
 nova = false

you must also start the run with the `blacklists/tempest-no-compute-blacklist` blacklist.
This contains a series of regexps that should prevent any tests that use the compute 
service from running.

The rally invocation will look like:

.. code-block:: shell
 rally verify start --skip-list ~/blacklists/tempest-no-compute-blacklist


Grab the list of tests from that run:

.. code-block:: shell
 ./tempest-tests-in-report.sh --uuid 06597b42-015b-4629-8ae5-14dfddf08f18 | ./tempest-tests-to-blacklist > /tmp/no-compute

expand regexps:

.. code-block:: shell
 python tempest-blacklist.py /tmp/no-compute > blacklists/no-compute

This will be used as the ``--skip-list` in the second run of rally.

Create skip list for a particular site
---------------------------------------

The skip lists are organised into a directory per site. Any identical files are symlinks.
These must be combined to generate the full skip list:

.. code-block:: shell
 cat blacklists/verne/* > /tmp/skip_list

expand regexps:

.. code-block:: shell
 python tempest-blacklist.py /tmp/skip_list > /tmp/skip_list2

Custom tempest
--------------

I am currently using these patches:

- https://review.opendev.org/#/c/656534/
- https://github.com/jovial/tempest/commits/feature/ironic_wait

to use the customisations just merge those changes into the tempest repo
created by rally, eg in:

``~/.rally/verification/verifier-65d56aef-dc91-4442-abc6-851c858ade21/repo/``

tempest.conf will need to modified to include the following:

.. code-block:: shell
  [compute_quotas]
  cores=-1
  ram=-1

Running the baremetal tests
---------------------------

You will need:

- the list of tests from the previous run no with compute. You should
  combine these with the any other skips lists, see: `Create skip list for project`
- a custom version of tempest that waits for compute resources to become available.
  This is especially important if you have enabled cleaning on the nodes.
- the compute service to be renabled in tempest.conf

We currently use the refestack list of tests as a known good subset of tests that doesn't take 
to long to run, to obtian these use:

.. code-block:: shell
 wget "https://refstack.openstack.org/api/v1/guidelines/next/tests?target=compute&type=required&alias=true&flag=false" -O ~/rally-kit/test-lists/next-test-list.txt

see: https://refstack.openstack.org/ for an updated list of tests.

the rally invocation will look like:

.. code-block:: shell
 rally verify start --load-list ~/rally-kit/test-lists/next-test-list.txt --skip-list /tmp/skip_list2 --xfail-list ~/rally-kit/expected-failures/verne --concurrency 1


it is important to run with concurrency==1 otherwise the test run will be unreliable.

Making sure the test set doesn't change with tempest version
-------------------------------------------------------------

You can use ``rally-tests-in-report.sh`` to generate a `--load-list`. This means that you will run the 
same of set of tests even across tempest upgrades (where new tests may be added). 
It is recommended that you do this for:

- the tests run without the compute service enabled
- the tests run with the compute service enabled

This way it will be esier to compare results.
