ansible-relayor
----------------
This is an ansible role for tor relay operators.
An introduction to relayor can be found **[here](https://medium.com/@nusenu/deploying-tor-relays-with-ansible-6612593fa34d)**.

Email Support: relayor-support AT riseup.net

The main focus of this role is to automate as many steps as possible for a tor relay
operator including key management (OfflineMasterKey).
Deploying a new tor server is as easy as adding a new host to the inventory,
no further manual configuration is required.

This role only manages tor instances as per the current settings and variables.
If you change the configuration after a complete playbook run, to reduce the number of tor instances, for example by
reducing the value of `tor_maxPublicIPs`, this role will not remove the previously configured tor instances
from your server. Tor instances on a server are identified by their IPv4 and ORPort combination.
Changing the ORPort (using the `tor_ports` variable) after initial rollout, effectively means creating new
tor instances (not changing them), this is the reason why changing the `tor_ports` variable should be avoided after the initial rollout.

Keeping the tor package updated (an important task of running a relay) is not in scope of this ansible role.
We recommend you enable automatic updates to keep your relay well maintained if your OS supports that.
The Tor Relay Guide contains instructions on how to enable automatic software updates for [Debian/Ubuntu](https://community.torproject.org/relay/setup/guard/debian-ubuntu/updates/)
and [FreeBSD](https://community.torproject.org/relay/setup/guard/freebsd/updates/).

This ansible role does not aim to support tor bridges.

Main benefits for a tor relay operator
--------------------------------------
- **automation** - no more manual setup tasks
- security: **[offline Ed25519 master keys](https://gitlab.torproject.org/legacy/trac/-/wikis/doc/TorRelaySecurity/OfflineKeys)** are generated on the ansible host and are never exposed to the relay
- **easy Ed25519 signing key renewal** (valid for 30 days by default - configurable)
- security: compartmentalization: every tor instance is run with a distinct user
- automatically makes use of IPv6 IPs (if available)
- automatic tor instance generation (two by default - configurable)
- enables tor's Sandbox feature by default on Debian-based systems
- easily choose between alpha/non-alpha releases (Debian/Ubuntu/FreeBSD only)
- easily restore a relay setup (the ansible host becomes a backup location for all keys out of the box)
- easily choose between exit relay/non-exit relay mode using a single boolean
- automatic deployment of a [tor exit notice html](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) page via tor's DirPort (on exits only)
- automatic MyFamily management
- **prometheus integration** (when enabled)
  - nginx reverse proxy config autogeneration to protect tor's MetricsPort (behind basic auth / HTTPS)
  - prometheus scrape config autogeneration for MetricsPort
  - blackbox-exporter scrape config autogeneration to monitor reachability of ORPorts and DirPorts
  - ship prometheus alert rules for tor

Installation
------------

This ansible role is available on galaxy https://galaxy.ansible.com/nusenu/relayor/

```ansible-galaxy install nusenu.relayor```

Requirements
------------
Control Machine Requirements

- do **not** run this role with `become: yes`
- tor >= 0.4.7
- python-netaddr package must be installed
- required commands: sort, uniq, wc, cut, sed, xargs
- openssl >= 1.0.0
- ansible >= 2.12.7
- bash under /bin/bash

Managed Node Requirements

- a non-root user with sudo permissions
- python
- static IPv4 address(es)
    - we can use multiple public IPs
    - if you have no public IP we will use a single private IP (and assume NAT)
- systemd (all Linux-based systems)

Prometheus Server Requirements (only when using prometheus features of this role)

- promtool must be installed on the prometheus server and in the PATH of the root user

Supported Operating Systems
---------------------------

- Debian 11, 12
- OpenBSD 7.2
- FreeBSD 13.2
- Ubuntu 22.04

Supported Tor Releases
-----------------------
- tor >= 0.4.7.x

Example Playbook
----------------

A minimal playbook using ansible-relayor to setup non-exit relays could look like this:

```yaml
---

- hosts: relays
  vars:
    tor_ContactInfo: relay-operator@example.com
  roles:
    - nusenu.relayor
```

For more examples see the playbook-examples folder.

Changed torrc defaults
----------------------

This role changes the defaults of the following torrc options to use safer options by default
but you can still explicitly configure them via `tor_config`:

* `NoExec` 0 -> 1
* `Sandbox` 0 -> 1 (on Debian only)

Role Variables
--------------
All variables mentioned here are optional.

* `tor_ContactInfo` string
    - Sets the relay's ContactInfo field.
    - This setting is mandatory.
    - Operators are encouraged to use the [ContactInfo Information Sharing Specification](https://nusenu.github.io/ContactInfo-Information-Sharing-Specification/) to publish useful contact information.

* `tor_signingkeylifetime_days` integer
    - all tor instances created by relayor run in [OfflineMasterKey](https://www.torproject.org/docs/tor-manual.html.en#OfflineMasterKey) mode
    - this setting defines the lifetime of Ed25519 signing keys in days
    - indirectly defines **how often you have to run your ansible playbook to ensure your relay keys do not expire**
    - **a tor instance in OfflineMasterKey mode automatically stops when his key/cert expires, so this is a crucial setting!**
    - lower values (eg. 7) are better from a security point of view but require more frequent playbook runs
    - default: 30

* `tor_config` dictionary
    - this dictionary contains torrc settings and their value, for available options see the 'SERVER OPTIONS' section in tor's manual.
    - each setting can only be set once (regardless what tor's manpage says)
    - this dictionary can be used to set any torrc option but NOT the following: `OfflineMasterKey`, `RunAsDaemon`, `Log`, `SocksPort`, `OutboundBindAddress`, `User`, `DataDirectory`, `ORPort`, `OutboundBindAddress`, `DirPort`, `SyslogIdentityTag`, `PidFile`, `MetricsPort`, `MetricsPortPolicy`, `ControlSocket`, `CookieAuthentication`, `Nickname`, `ExitRelay`, `IPv6Exit`, `ExitPolicy`, `RelayBandwidthRate`, `RelayBandwidthBurst`, `SigningKeyLifetime`

* `tor_ports` dictionary
    - This var allows you to
        - select tor's ORPort and DirPort
        - decide how many tor instances you want to run per IP address (default 2) - make sure to not run more than allowed per IP address
    - disable DirPorts by setting them to 0
    - HINT: choose ORPorts wisely and *never* change them again, at least not those deployed already, adding more without changing deployed once is fine.
    - tor's 'auto' feature is NOT supported
    - default:
        - instance 1: ORPort 9000, DirPort 9001
        - instance 2: ORPort 9100, DirPort 9101

* `tor_offline_masterkey_dir` folderpath
    - default: ~/.tor/offlinemasterkeys
    - Defines the location where on the ansible control machine we store relay keys (Ed25519 and RSA)
    - Within that folder ansible will create a subfolder for every tor instance.
    - see the [documentation](https://github.com/nusenu/ansible-relayor/wiki/How-to-migrate-all-tor-instances-of-one-server-to-another) if you want to migrate instances to a new server
    - **note**: do not manually mangle file and/or foldernames/content in these tor DataDirs

* `tor_nickname` string
    - defines the nickname tor instances will use
    - all tor instances on a host will get the same nickname
    - to use the server's hostname as the nickname set it to {{ ansible_hostname }}
    - non-alphanum chars are automatically removed and nicknames longer than 19 characters are truncated to meet tor's nickname requirements
    - tor_nicknamefile overrules this setting
    - default: none

* `tor_nicknamefile` filepath
    - this is a simple comma separated csv file stored on the ansible control machine specifying nicknames
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: nickname
    - one instance per line
    - all instances MUST be present in the csv file
    - non-alphanum chars are automatically removed and nicknames longer than 19 characters are truncated to meet tor's nickname requirements
    - default: not set

* `tor_gen_ciiss_proof_files` boolean
    - generate the rsa-fingerprint.txt and ed25519-master-pubkey.txt proof files on the control machine for publishing according to [ContactInfo spec](https://nusenu.github.io/ContactInfo-Information-Sharing-Specification/#proof)
    - default paths are: ~/.tor/rsa-fingerprint.txt and ~/.tor/ed25519-master-pubkey.txt
    - the files are overwritten if they exist
    - the location of the output folder can be configured using the variable `tor_ciiss_proof_folder`
    - the filename is hardcoded to the one required by the specification and can not be configured
    - default: False

* `tor_ciiss_proof_folder` folderpath
    - defines the output folder for generated proof files
    - default: ~/.tor

* `tor_LogLevel` string
    - sets tor's LogLevel
    - default: notice

* `tor_alpha` boolean
    - Set to True if you want to use Tor alpha version releases.
    - Note: This setting does not ensure an installed tor is upgraded to the alpha release.
    - This setting is supported on Debian/Ubuntu/FreeBSD only (ignored on other platforms).
    - default: False

* `tor_nightly_builds` boolean
    - Set to True if you want to use Tor nightly builds repo from deb.torproject.org.
    - nightly builds follow the tor git main branch.
    - Only supported on Debian and Ubuntu (ignored on other platforms).
    - default: False

* `tor_ExitRelay` boolean
    - You have to set this to True if you want to enable exiting for all or some tor instances on a server
    - If this var is not True this will be a non-exit relay
    - If you want to run a mixed server (exit and non-exit tor instances) use `tor_ExitRelaySetting_file` for per-instance configuration in additon to this var
    - default: False

* `tor_ExitRelaySetting_file` filepath
    - this is a simple comma separated csv file stored on the ansible control machine defining the `ExitRelay` torrc setting for each tor instance (instead of server-wide)
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: "exit" for exit tor instances, any other value (including empty) for non-exit tor instances
    - this var is ignored if tor_ExitRelay is False

* `tor_RelayBandwidthRate_file` filepath
    - this is a simple comma separated csv file stored on the ansible control machine defining the `RelayBandwidthRate` torrc setting for each tor instance (instead of server-wide)
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: value as accepted by `RelayBandwidthRate` (see tor manpage)

* `tor_RelayBandwidthBurst_file` filepath
    - this is a simple comma separated csv file stored on the ansible control machine defining the `RelayBandwidthBurst` torrc setting for each tor instance (instead of server-wide)
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: value as accepted by `RelayBandwidthBurst` (see tor manpage)

* `tor_ExitNoticePage` boolean
    - specifies whether we display the default tor exit notice [html page](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) on the DirPort
    - only relevant if we are an exit relay
    - default: True

* `tor_exit_notice_file` filepath
    - path to a HTML file on the control machine that you would like to display (via the DirPort) instead of the default [tor-exit-notice.html](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) provided by the Tor Project
    - only relevant if we are an exit relay and if tor_ExitNoticePage is True

* `tor_AbuseEmailAddress` email-address
    - if set this email address is used on the tor exit notice [html page](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) published on the DirPort
    - you are encouraged to set it if you run an exit
    - only relevant if we are an exit relay
    - Note: if you use your own custom tor-exit-notice template this var is ignored if you do not include it in your template.
    - default: not set

* `tor_ExitPolicy` array
    - specify your custom exit policy
    - only relevant if `tor_ExitRelay` is True
    - see defaults/main.yml for an example on how to set it
    - default: reduced exit policy (https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy)

* `tor_ExitPolicy_file` filepath
    - this is a simple semicolon separated csv file stored on the ansible control machine defining the `ExitPolicy` torrc setting for each tor instance (instead of server-wide)
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: value as accepted by `ExitPolicy` (see tor manpage)
    - example content: "myrelay-192.168.1.1_443;reject *:25,reject *:123"
    - only relevant if `tor_ExitRelay` is True
    - this can be combined with the `tor_ExitPolicy` setting and will override it (this is more specific)
    - only tor instances that you want to have a specific exit policy for are required to be listed in the file (others can be omitted)
    - default: not set

* `tor_maxPublicIPs` integer
    - Limits the amount of public IPs we will use to generate instances on a single host.
    - Indirectly limits the amount of instances we generate per host.
    - default: 1

* `tor_IPv6` boolean
    - autodetects if you have IPv6 IPs and enables an IPv6 ORPort accordingly
    - you can opt-out by setting it to False
    - default: True

* `tor_IPv6Exit` boolean
    - enables IPv6 exit traffic
    - only relevant if `tor_ExitRelay` and `tor_IPv6` are True and we have an IPv6 address
    - default: True (unlike tor's default)

* `tor_enableMetricsPort` boolean
    - if True enable tor's MetricsPort on the localhost IP address 127.0.0.1 and allow the same IP to access it (MetricsPortPolicy)
    - this is a relayor beta feature and will change in the future to use the safer [unix socket](https://gitlab.torproject.org/tpo/core/tor/-/issues/40192) option once that becomes available
    - enabling this setting automatically disables `OverloadStatistics` if it is not enabled explicitly (so tor will not publish/upload the data to directory authorities because we use MetricsPort locally)
    - default: False

* `tor_prometheus_host` hostname
    - this variable is only relevant if `tor_enableMetricsPort` or `tor_blackbox_exporter_host` is set
    - if you want to enable relayor's prometheus integration you have to set this variable to your prometheus host
    - it defines on which host ansible should generate the prometheus scrape configuration to scrape tor's MetricsPort
    - this host must be available in ansible's inventory file
    - default: undefined (no scrape config is generated)

* `tor_prometheus_confd_folder` folderpath
    - only relevant if you want to use prometheus
    - this folder most exist on `tor_prometheus_host`
    - relayor places prometheus scrape_configs in this folder
    - the prometheus global config section should be in this folder named 1_prometheus.yml
    - we assemble all files in that folder in string sorting order into a single prometheus.yml output file since prometheus does not support conf.d style folders out of the box
    - default: `/etc/prometheus/conf.d`

* `tor_prometheus_config_file` filepath
    - only relevant if you want to use prometheus
    - this var defines the path of the global prometheus configuration file on `tor_prometheus_host`
    - we backup the file in the same folder before generating a new one
    - this is a security sensitive file as it contains credentials for tor's MetricsPort
    - file owner: root, group: `tor_prometheus_group`, permissions: 0640
    - default: `/etc/prometheus/prometheus.yml`

* `tor_MetricsPort_offset` integer
    - defines the TCP MetricsPort used on the first tor instance running on a host
    - additional tor instances will use an incremented port number 33301, 33302, ...
    - so if you run N instances on a host, the next N-1 ports after this port have to be unused on 127.0.0.1 so tor can use them for MetricsPort
    - default: 33300

* `tor_prometheus_scrape_file` filename
    - only relevant if `tor_prometheus_host` is defined and `tor_enableMetricsPort` or `tor_blackbox_exporter_host` is set
    - defines the filename for per server [scrape_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config) files
      on the prometheus server inside the `tor_prometheus_confd_folder`
    - the filename MUST be host specific, each host has its own scrape config file on the prometheus server to support the ansible-playbook `--limit` cli option
    - depending on `tor_enableMetricsPort` and `tor_blackbox_exporter_host`, the scrape config files will contain scrape jobs for the tor
      MetricsPort (behind a reverse proxy for TLS/basic auth) and/or scrape jobs for ORPort/DirPort TCP probes via blackbox exporter
    - the file content is sensitive (contains scrape credentials) and gets these file permissions: 0640 (owner: root, group: `tor_prometheus_group`)
    - the generated scrape config files will automatically be enriched with a few useful prometheus labels depending on your torrc settings, see the "Prometheus Labels" section in this README
    - default: `tor_{{ ansible_fqdn }}.yml`

* `tor_prometheus_group` string
    - only relevant if you want to use prometheus
    - defines the group name used for prometheus file permissions (prometheus.yml, scrape config files, alert rules file)
    - default: prometheus

* `tor_prom_labels` dictionary
    - arbitrary number of prometheus label value pairs
    - can be set on a per server level, not on a per instance level
    - for an example see `defaults/main.yml`
    - default: empty dictionary

* `tor_blackbox_exporter_host` hostname:port
    - when set, relayor adds the necessary prometheus scrape config for blackbox exporter TCP propes in the file defined by `tor_prometheus_scrape_file`
    - monitors all relay ORPorts and when set DirPorts on IPv4 and IPv6 (if enabled) using a TCP connect check
    - this feature is not supported on relays behind NAT
    - defines where prometheus finds the blackbox exporter, it can also run on the prometheus server itself, in that case it would be 127.0.0.1:9115
    - the host is written into the resulting prometheus scrape config
    - blackbox_exporter must have a simple [tcp_probe](https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md#tcp_probe) module named "tcp_connect" configured
    - relayor does not install or configure [blackbox_exporter](https://github.com/prometheus/blackbox_exporter)
    - default: undefined

* `tor_blackbox_exporter_scheme` string
    - defines the protocol prometheus uses to connect to the blackbox exporter (http or https)
    - default: http

* `tor_blackbox_exporter_username` string
    - only relevant when `tor_blackbox_exporter_host` is set
    - allows you to define the username if your blackbox exporter requires HTTP basic authentication
    - if you do not set a username the scrape config will not include HTTP basic auth credentials
    - default: undefined (no HTTP basic auth)

* `tor_blackbox_exporter_password` string
    - only relevant when `tor_blackbox_exporter_host` is set
    - allows you to the the username if your blackbox exporter requires HTTP basic auth
    - the default generates a 20 character random string using the Ansible password lookup
    - default: `"{{ lookup('password', '~/.tor/prometheus/blackbox_exporter_password') }}"`

* `tor_metricsport_nginx_config_file` filepath
    - this variable is only relevant if `tor_enableMetricsPort` is True and `tor_prometheus_host` is set
    - it defines the filepath where the nginx reverse proxy configuration for MetricsPort will be stored on the relay
    - this file has to be included in your webserver configuration on the relay to make MetricsPort accessible for remote prometheus scraping
    - the folder has to be present on the server already (relayor does not create it)
    - default: `/etc/nginx/promexporters/tor_metricsports_relayor.conf`

* `tor_gen_prometheus_alert_rules` boolean
    - only relevant when `tor_enableMetricsPort` is enabled
    - set to `True` if you want to generate [prometheus alert rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) on the prometheus server (`tor_prometheus_host`)
    - the file location is defined by `tor_prometheus_rules_file`
    - default: false (no rules are generated)

* `tor_prometheus_rules_file` filepath
    - only relevant when `tor_gen_prometheus_alert_rules` is `True`
    - defines where on the prometheus server (`tor_prometheus_host`) relayor will generate the rules file (the folder has to be present)
    - the file has to be in the folder that is included by your prometheus config (rule_files) and usually is required to end with .rules
    - relayor ships a default set of alert rules and you can optionally add your custom alert rules as well (via `tor_prometheus_custom_alert_rules`)
    - file owner/group: root, file permissions: 0644
    - default: `/etc/prometheus/rules/ansible-relayor.rules`

* `tor_prometheus_alert_rules` dictionary
    - defines the prometheus alert rules
    - rules are validated using promtool automatically
    - see `defaults/main.yml` for the default rules

* `tor_prometheus_custom_alert_rules` dictionary
    - if you want to add your user defined rules, add them to this dictinary, it expects the same format as in `tor_prometheus_alert_rules`
    - rules defined in this dictionary are also written to `tor_prometheus_rules_file`
    - this allows you to make use of new rules shipped by new relayor versions while still maintaining your user defined rules
    - rules are validated using promtool automatically
    - default: undefined

* `tor_gen_metricsport_htpasswd` boolean
    - this variable is only relevant if `tor_enableMetricsPort` is True
    - when this var is set to True, we create the htpasswd file that can be used by a webserver on the relay to protect tor's MetricsPort with HTTP basic auth
    - the file will be owned by root and readable by the webserver's group (www-data/www - depending on the OS)
    - we do NOT install the webserver, use another role for that.
    - the password is [automatically generated](https://docs.ansible.com/ansible/2.9/plugins/lookup/password.html) and 20 characters long (each server gets a distinct password)
    - the path to the file on the relay is defined in `tor_metricsport_htpasswd_file`
    - the plaintext password is written to a file on the ansible control machine (see `tor_prometheus_scrape_password_folder`)
    - default: True

* `tor_metricsport_htpasswd_file` filepath
    - only relevant if `tor_enableMetricsPort` and `tor_gen_metricsport_htpasswd` are set to True
    - it defines the filepath to the htpasswd file (containing username and password hash) on the relay
    - default: `/etc/nginx/tor_metricsport_htpasswd`

* `tor_prometheus_scrape_password_folder` folderpath
    - only relevant if `tor_enableMetricsPort` is True
    - ansible will automatically generate one unique and random 20 character password per host (not per tor instance) to protect the MetricsPort via nginx (http auth)
    - this variable defines the folder where ansible will store the passwords in plaintext (password lookup)
    - the filenames within that folder match the hostname (inventory_hostname) and can not be configured
    - the variable must contain a trailing `/`
    - default: `~/.tor/prometheus/scrape-passwords/`

* `tor_prometheus_scrape_port` integer
    - defines what destination port is used to reach the scrape target (`MetricsPort`) via nginx
    - default: 443

* `tor_enableControlSocket` boolean
    - if True create a ControlSocket file for every tor instance (i.e. to be used for nyx)
    - access control relies on filesystem permissions
    - to give a user access to a specific tor instance's controlsocket file you
    - have to add the user to the primary group of the tor instance
    - the path to the socket file(s) is /var/run/tor-instances/instance-id/control
    - this setting affects all instances on a given server
    - per instance configuration is not supported
    - default: False

* `tor_freebsd_somaxconn` integer
    - configure kern.ipc.somaxconn on FreeBSD
    - by default we increase this value to at least 1024
    - if the value is higher than that we do not touch it

* `tor_freebsd_nmbclusters` integer
    - configure kern.ipc.nmbclusters on FreeBSD
    - by default we increase this value to at least 30000
    - if the value is higher than that we do not touch it

* `tor_package_state` string
    - specify what package state the tor package should have
    - possible values: present, latest (not supported on BSDs)
    - Note: The repository metadata is not updated, so setting this to latest does not give you any guarantees if it actually is the latest version.
    - default: present

* `tor_binary` string
    - name of the tor binary on the control machine used to generate the offline keys
    - if the tor binary is not named "tor" on your control machine, you have to change the default (for example on Whonix workstations)
    - default: tor

Prometheus Labels
-----------------

When `tor_enableMetricsPort` is enabled we also populate the following prometheus labels:

* `id`: identifies the tor instance by IP_ORPort. Example value: 198.51.100.10_9000
* `relaytype`: value is either "exit" or "nonexit" depending on `tor_ExitRelay`
* `tor_nickname`: when nicknames are defined (`tor_nicknamefile` or `tor_nickname`) this label is added
* `service`: "torrelay"

You can add additional prometheus labels using `tor_prom_labels`.


Available Role Tags
--------------------

Using ansible tags is optional but allows you to speed up playbook runs if
you are managing many servers.

There are OS specific tags:

* debian (includes ubuntu)
* freebsd
* openbsd

Task oriented tags:

* **renewkey** - takes care of renewing online Ed25519 keys only (assumes that tor instances are fully configured and running already)
* install - installs tor but does not start or enable it
* createdir - creates (empty) directories on the ansible host only, useful for migration
* promconfig - regenerates prometheus related configs (scrape config, blackbox exporter, nginx)
* reconfigure - regenerates config files (tor and promconfig) and reloads tor (requires previously configured tor instances)

So if you have a big family and you are about to add an OpenBSD host you typically
make two steps

1. install the new server by running only against the new server (-l) and only the os specific tag (openbsd)

    `ansible-playbook yourplaybook.yml -l newserver --tags openbsd`

2. then reconfigure all servers (MyFamily) by running the 'reconfigure' tag against all servers.

    `ansible-playbook yourplaybook.yml --tags reconfigure`

Security Considerations
------------------------
This ansible role makes use of tor's OfflineMasterKey feature without requiring any manual configuration.

The offline master key feature exposes only a temporary signing key to the relay (valid for 30 days by default).
This allows to recover from a complete server compromise without losing a relay's reputation (no need to bootstrap a new permanent master key from scratch).

Every tor instance is run with a distinct system user. A per-instance user has only access to his own (temporary) keys, but not to those of other instances.
We do not ultimately trust every tor relay we operate (we try to perform input validation when we use relay provided data on the ansible host or another relay).

**Be aware that the ansible control machine stores ALL your relay keys (RSA and Ed25519) - apply security measures accordingly.**

If you make use of the prometheus integration the ansible control machine will also store all your prometheus scrape credentials under `~/.tor/prometheus/`.
Rotating these credentials is very easy though: You can simply remove that folder and run ansible-playbook again.

Every tor server host gets its own set of prometheus credentials, so a compromised host should not allow them to scrape all other hosts.

Integration Testing
-----------------------

This ansible role comes with a .kitchen.yml file, that can be used
to test relayor - using different configurations - against Vagrant Virtualbox machines.
It is primarily used for development/integration testing (spot regressions)
but you can also use it to get familiar with relayor in such a local playground environment.
These tor relays will not join the network since they are only created for testing purposes.

kitchen will download Vagrant boxes from Vagrant cloud to create test VMs.

To get started install the required gem packages:

```bash
gem install test-kitchen kitchen-ansiblepush kitchen-vagrant
```

List available test instances with `kitchen list`.

Then you can run all tests or just select specific instances, for example: `kitchen test t-guard-debian-10`.

Note that to run tests, you also need Vagrant and VirtualBox.

Origins
-------
https://github.com/david415/ansible-tor (changed significantly since then)
