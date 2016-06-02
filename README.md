ansible-relayor
----------------
This is an ansible role for tor relay operators.

The main focus of this role is to automate as many steps as possible for a tor relay
operator including key management (OfflineMasterKey).
Deploying a new tor server is as easy as adding a new host to the inventory,
no further manual configuration is required.

Main benefits for a tor relay operator
--------------------------------------
- security: **offline Ed25519 master keys** are generated on the ansible host and are never exposed to the relay (OfflineMasterKey)
- **easy Ed25519 signing key renewal** (valid for 30 days by default - configurable)
- security: compartmentalization: every tor instance is run with a distinct user
- automatically makes use of IPv6 IPs (if available)
- **automatic MyFamily management**
- automatic tor instance generation (two per available IP address by default - configurable)
- easily choose between exit relay/non-exit relay mode using a single boolean
- easily restore a relay setup (the ansible host becomes a backup location for all keys out of the box)

Requirements
------------
ansible host:

- tor >= 0.2.7
- ansible >= 1.9.6 < 2.0
- python-netaddr package must be installed

target hosts:

- a non-root user with sudo
- python 2 under /usr/bin/python

Supported Operating Systems
---------------------------

- Debian 8
- CentOS 7 (incl. SELinux support)
- OpenBSD 5.9
- FreeBSD 10.x
- Ubuntu 16.04
- Fedora 23

Supported Tor Releases
-----------------------
- tor >= 0.2.7.5


Role Variables
--------------
All variables mentioned here are optional.

* `tor_offline_masterkey_dir`
    - default: ~/.tor/offlinemasterkeys
    - Defines the location where on the ansible host relay keys (ed25519 and RSA) are stored.
    - Within that folder ansible will create a subfolder for every tor instance.

* `tor_signingkeylifetime_days` integer
    - defines the lifetime of Ed25519 signing keys in days
    - indirectly defines **how often you have to run your ansible playbook to ensure keys do not expire**
    - lower values (eg. 7) are better from a security point of view but require more frequent playbook runs
    - default: 30

* `tor_LogLevel`
    - specify tor's loglevel (minSeverity)
    - possible values: debug, info, notice, warn and err
    - logs will go to syslog only (distinct files are not supported)
    - default: notice

* `tor_ContactInfo`
    - Sets the relay's ContactInfo field.

* `tor_IPv6` boolean
    - default: True (autodetects if you have IPv6 IPs and enables support for it accordingly)
    - you can opt-out by setting it to False

* `tor_nickname`
    - defines the nickname tor instances will use
    - up to 19 chars long, must contain only the characters [a-zA-Z0-9]
    - all tor instances on a host will get the same nickname
    - to use the server's hostname as the nickname set it to {{ ansible_hosname }}
    - tor_nicknamefile overrules this setting
    - default: none

* `tor_nicknamefile` /path/to/file.csv
    - this is a simple comma separated csv file stored on the ansible host specifying nicknames
    - first column: instance identifier (inventory_hostname-ip_orport)
    - second column: nickname
    - one instance per line
    - all instances MUST be present in the csv file
    - default: none

* `tor_ExitRelay` boolean 
    - You will want to set this to True if you want to run exit relays.
    - default: False

* `tor_ExitNoticePage` boolean
    - specifies whether we display the default tor exit notice [html page](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) on the DirPort
    - only relevant if we are an exit
    - default: True

* `tor_AbuseEmailAddress` email-address
    - if set this email address is used on the tor exit notice [html page](https://gitweb.torproject.org/tor.git/plain/contrib/operator-tools/tor-exit-notice.html) published on the DirPort
    - you are encouraged to set it if you run an exit
    - only relevant if you run exits

* `tor_ExitPolicy`
    - specify your custom exit policy
    - is only relevant if tor_ExitRelay is True
    - default: reduced exit policy (https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy)

* `tor_ports`
    - This var allows you to
        - select tor's ORPort and DirPort
        - reduce the number of Tor instances created per IP address
    - disable DirPorts by setting them to 0
    - HINT: choose them wisely and *never* change them again ;)
    - default:
        - instance 1: ORPort 9000, DirPort 9001
        - instance 2: ORPort 9100, DirPort 9101

* `tor_v4ips`
    - If you want to use only specific IPv4 addresses for Tor.
    - Makes only sense in host_vars context.

* `tor_maxips`
    - Limits the amount of IPs we will use to generate instances on a single host.
    - Indirectly limits the amount of instances we generate per host.
    - If tor_ips is set, tor_maxips has no effect.
    - default: 3

* `tor_enableControlSocket`
    - will create a ControlSocket file named 'controlsocket' in every instance's datadir
    - authentication relies on filesystem permissions
    - default: False

* `freebsd_somaxconn`
    - configure kern.ipc.somaxconn on FreeBSD
    - by default we increase this value to at least 1024
    - if the value is higher than that we do not touch it

* `freebsd_nmbclusters`
    - configure kern.ipc.nmbclusters on FreeBSD
    - by default we increase this value to at least 30000
    - if the value is higher than that we do not touch it

This role supports most torrc options documented in the 'SERVER OPTIONS'
section of tor's manual. Set them via 'tor_OptionName'.
Have a look at templates/torrc if you want to have list of supported
options.

Available Role Tags
--------------------

Using ansible tags is optional but allows you to speed up playbook runs if
you are managing many servers.

There are OS specific tags:

* debian (includes ubuntu)
* centos
* fedora
* freebsd
* openbsd

Task oriented tags:

* **renewkey** - takes care of renewing online Ed25519 keys only (assumes that tor instances are fully configured and running already)
* install - installs tor but does not start or enable it
* createdir - creates (empty) directories (locally and remote) and the tor users required to setup fs permissions, usefull for migration
* reconfigure - regenerates torrc files and reloads tor (requires previously configured tor instances)

So if you have a big family and you are about to add an OpenBSD host you typically
make two steps

1. install the new server by running only against the new server (-l) and only the os specific tag (openbsd)

    `ansible-playbook tor.yml -l newserver --tags openbsd`

2. then reconfigure all servers (MyFamily) by running the 'reconfigure' tag against all servers.

    `ansible-playbook tor.yml --tags reconfigure`

Security Considerations
------------------------
This ansible role makes use of tor's OfflineMasterKey feature without requiring any manual configuration.

The offline master key feature exposes only a temporary signing key to the relay (valid for 30 days by default).
This allows to recover from a complete server compromize without loosing a relay's reputation (no need to bootstrap a new permanent master key from scratch).

Every tor instance is run with a distinct system user. A per-instance user has only access to his own (temporary) keys, but not to those of other instances.
We do not ultimately trust every tor relay we operate (we try to perform input validation when we use relay provided data on the ansible host or another relay).

**Be aware that the host running ansible stores ALL your relay keys (RSA and Ed25519) - apply security measures accordingly.**


Reporting Security Bugs
-----------------------

Feel free to submit them in the public issue tracker,
or if you like via GPG encrypted email.

Origins
-------
https://github.com/david415/ansible-tor (changed significantly since then)
