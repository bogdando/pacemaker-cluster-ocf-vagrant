# pacemaker-cluster-ocf-vagrant

[Packer Build Scripts](https://github.com/bogdando/packer-atlas-example)
| [Docker Image (Ubuntu 15.10)](https://hub.docker.com/r/bogdando/pacemaker-cluster-ocf-wily/)
| [Docker Image (Ubuntu 16.04)](https://hub.docker.com/r/bogdando/pacemaker-cluster-ocf-xenial/)

A Vagrantfile to bootstrap a Pacemaker cluster and install a given
[OCF RA](http://www.linux-ha.org/wiki/OCF_Resource_Agents) resource under test.

## Vagrantfile

Supports only docker (experimental) provider.
Required vagrant plugins: vagrant-triggers.
TODO(bogdando): add support for debian/centos/rhel images as well.

* Spins up two VM nodes ``[n1, n2]`` with predefined IP addressess
  ``10.10.10.2-3/24`` by default. Use the ``SLAVES_COUNT`` env var, if you need
  more nodes to form a cluster. Note, that the ``vagrant destroy`` shall accept
  the same number as well!
* Creates a corosync cluster with disabled quorum and STONITH.
* Launches the given OCF RA under test.

Note, that constants from the ``Vagrantfile`` may be as well configred as
``vagrant-settings.yaml_defaults`` or ``vagrant-settings.yaml`` and will be
overriden by environment variables, if specified.

Also note, that for workarounds implemented for the docker provider made
the command ``vagrant ssh`` not working. Instead use the
``docker exec -it n1 bash`` or suchlike.

## Known issues

* A Pacemaker may behave strange in VM-like containers: ``crm_node -l`` may start
  reporting empty nodes lists or pacemakerd may die for a some strange reason.
  That was seen when using custom docker run commands, which are not ``/sbin/init``.

* For the docker provider, a networking is [not implemented](https://github.com/mitchellh/vagrant/issues/6667)
  and there is no [docker-exec privisioner](https://github.com/mitchellh/vagrant/issues/4179)
  to replace the ssh-based one. So I put ugly workarounds all around to make
  things working more or less.

* If ``vagrant destroy`` fails to teardown things, just repeat it few times more.
  Or use ``docker rm -f -v`` to force manual removal, but keep in mind that
  that will likely make your docker images directory eating more and more free
  space.

* Make sure there is no conflicting host networks exist, like
  ``packer-atlas-example0`` or ``vagrant-libvirt`` or the like. Otherwise nodes may
  become isolated from the host system.

## Troubleshooting

You may want to use the command like:
```
VAGRANT_LOG=info SLAVES_COUNT=2 vagrant up 2>&1| tee out
```

There was added "Crafted:", "Executing:" log entries for the
provision shell scripts.

For the Foo OCF RA you may use the command like:
```
OCF_ROOT=/usr/lib/ocf /usr/lib/ocf/resource.d/foo-provider/foo-ra monitor
```

It puts its logs under ``/var/log/syslog`` from the `lrmd` or a given
`HA_LOGTAG` program tag.

## Jepsen tests

[Jepsen](https://github.com/aphyr/jepsen) is good to find out how resilient,
consistent, available your distributed system is. For OCF RA acting as
clusterers, it may be nice to know if the cluster recovers from network
partitions well. And history validation comes just as a free bonus :-)
Although the jepsen test results may be ignored because it maybe rather
related to the cluster/distributed system itself than to the OCF RA clusterer
or a Pacemaker.

The idea is to bootstrap Pacemaker cluster with a cluster assembpled by the
OCF RA under test, and allow Jepsen to continuousely do hammering of the cluster
with Nemesis strikes. Then check if the cluster has been recovered. And of cause
you may want to look into the
[history validation](https://aphyr.com/posts/314-computational-techniques-in-knossos)
results as well. Hopefully, that would give you insights on the cluster
(or a Pacemaker) configuration settings!

Also note that both smoke and jepsen tests will perform an *integration testing*
of the complete setup, which is Corosync/Pacemaker cluster plus the subject
cluster on top. Keep in mind that network partitions may kill the Pacemaker
cluster as well.

To proceed with jepsen tests, firstly create an ssh key with:
```
cat /dev/random | ssh-keygen -b 1024 -t rsa -f /tmp/sshkey -q -N ""
```
Secondly, update `./conf` files as required for a test case and define the env
settings variables in the `./vagrant-settings.yaml_defaults` file. For example,
let's use `jepsen_app: rabbit_ocf_pcmk`, `rabbit_ver: 3.5.7`.

Then set `use_jepsen: "true"` in the env settings  and run ``vagrant up``.
It launches a control node n0 and five nodes named n1, n2, n3, n4, n5. Jepsen logs
and results may be found in the shared volume named `jepsen`, in the `/logs`.

NOTE: The `jepsen` volume contains a shared state, like the lein docker image and
the jepsen repo/jarfile/results, for consequent vagrant up/destroy runs. If
something went wrong, you can safely delete it. Then it will be recreated from the
scratch as well.

To run lein commmands, use ``docker exec -it jepsen lein foo`` from the control node.
For example, for the `jepsen_app: jepsen`, it may be:
```
docker exec -it jepsen lein test :only jepsen.core-test/ssh-test
```
or just ``lein test``, or even something like
```
bash -xx /vagrant/vagrant_script/lein_test.sh foo_ocf_pcmk
```

## Examples
See the [RabbitMQ OCF RA](https://github.com/bogdando/rabbitmq-cluster-ocf-vagrant)
example repo, which is based on this one.
