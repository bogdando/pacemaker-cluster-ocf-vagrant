# pacemaker-cluster-ocf-vagrant

Docker images (debian:jessy based)
[Pacemaker](https://hub.docker.com/r/bogdando/pacemaker/)
| [Corosync](https://hub.docker.com/r/bogdando/corosync/)
| [Pcs/Crm tools](https://hub.docker.com/r/bogdando/corosync/pcscrm)

A Vagrantfile to bootstrap a Corosync/Pacemaker cluster and install a given
[OCF RA](http://www.linux-ha.org/wiki/OCF_Resource_Agents) resource under test,
hence a `runner`. A runner as well contains some required tools like the
`pcs` or `curl` or `iptables`. A Corosync/Pacemaker run as a foreground
processes in a lightweight containers, hence `apps`.

## Vagrantfile

Supports only docker (experimental) provider.
Required vagrant plugins: vagrant-triggers. Requires a Docker >=v1.12.

* Spins up a two containers for a Pacemaker apps made as a cluster and
  (linked)[https://github.com/docker/docker/blob/master/docs/reference/run.md#pid-settings---pid]
  via IPC/pid/net spaces to a two more Corosync container apps as well. On top of the Pacemaker apps,
  links a `runner` wrapper containers named n1, n2. The runners will
  configure a Pacemaker OCF RA resource under test, like a DB/MQ clusters,
  and will be accessed via SSH as a generic VM hosts by a Jepsen, if enabled.

Use the ``IP24NET`` and ``SLAVES_COUNT`` or a runner image/mounts related env
vars, if you need more instances or custom IPs in the Corosync cluster, or
custom image/mounts for the runners.

Note, that constants from the ``Vagrantfile`` may be as well configred as
``vagrant-settings.yaml_defaults`` or ``vagrant-settings.yaml`` and will be
overriden by environment variables, if specified.

Also note, that for workarounds implemented for the docker provider made
the command ``vagrant ssh`` not working. Instead use the
``docker exec -it n1 bash`` or suchlike.

## Known issues

* For the docker provider, a networking is [not implemented](https://github.com/mitchellh/vagrant/issues/6667)
  and there is no [docker-exec privisioner](https://github.com/mitchellh/vagrant/issues/4179)
  to replace the ssh-based one. So I put ugly workarounds all around to make
  things working more or less.

* If ``vagrant destroy`` fails to teardown things, just repeat it few times more.
  Or use ``docker rm -f -v`` to force manual removal, but keep in mind that
  that will likely make your docker images directory eating more and more free
  space.

* If the terminal session looks "broken" after the ``vagrant up/down``, issue a
  ``reset`` command as well.

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
Secondly, define the env settings variables in the
`./vagrant-settings.yaml(_defaults)` files. For example, let's use
`jepsen_app: noop`, `jepsen_testcase: ssh-test` and

Then set `use_jepsen: "true"` in the env settings  and run ``vagrant up``.
It launches a five runners named n{1,5} and an additional control node runner
container n0. Jepsen logs and results may be found in the shared volume named
`jepsen`, in the `/logs`.

NOTE: The `jepsen` volume contains a shared state, like the lein docker image and
the jepsen jarfile/test results. It will be mounted to the n0 runner and reused
across a consequent vagrant up/destroy runs. If something went wrong, you can safely
delete it. Then it will be recreated from the scratch as well.

To collect logs at the host OS under the `/tmp/results.tar.gz`, use the command like:
```
docker run -it --rm -e "GZIP=-9" --entrypoint /bin/tar -v jepsen:/results:ro -v
/tmp:/out ubuntu cvzf /out/results.tar.gz /results/logs
```

To run lein commmands, use ``docker exec -it jepsen lein foo`` from the control node.
For example, for the `jepsen_app: jepsen`, it may be:
```
docker exec -it jepsen lein test :only jepsen.core-test/ssh-test
```
or just ``lein test``, or even something like
```
bash -xx /vagrant/vagrant_script/lein_test.sh foo_ocf_pcmk
PURGE=true ./vagrant/vagrant_script/lein_test.sh noop ssh-test
```
