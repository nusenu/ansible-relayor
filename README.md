ansible-relayor
----------------
This is an ansible role for tor relay operators.

The main focus of this role is to automate as many steps as possible for a Tor relay
operator when deploying Tor servers.

Goal:
Adding a new Tor server should be as easy as adding a new host to the inventory,
no further manual configuration should be required.

The main benefits for a relay operator are:
- ed25519 master keys are generated on the ansible host and are never exposed to the relay (OfflineMasterKey=1)
- automatic instance generation (two per available IP address)
- automatic MyFamily management
- easily choose between exit relay/non-exit relay mode using a single boolean
- boolean for stable vs. alpha Tor releases (Fedora and CentOS only)
- easy relay restore from key backups (generated and stored on the ansible host out of the box)

DO NOT USE THIS BRANCH on anything real yet.

Requirements
------------
- tor 0.2.7.x on the ansible host
- systemd (Linux systems)
- ansible >= 1.9.4
- a non-root user with passwordless sudo on the target systems for ansible
- the usual ansible requirements (python on the target system under /usr/bin/python)

Supported Operating Systems
---------------------------
- Debian 8
- CentOS 7 (incl. SELinux support)
- OpenBSD 5.8
- FreeBSD 10.1, 10.2
- Ubuntu 15.10 (incl. AppArmor support)
- Fedora 23

Supported Tor Releases
-----------------------
- 0.2.7.x

Example Tor Relay Playbook (simple)
------------------------------------

This playbook will use defaults and create two non-exit Tor instances for
every available IP address on the host. 
If the host has 3 IP addresses you will end up with 6 Tor instances (including DirPorts). 
The following TCP ports will be used for ORPort and DirPort listeners:
9000,9001,9100,9101
(if these ports are already in use, things will fail)

```yml
---

- hosts: relays
  roles:
   - ansible-relayor
```

Role Variables
--------------
All variables mentioned here are optional.

* `tor_syslog` boolean
   - Set to True to enable logging to syslog. False by default.

* `tor_ContactInfo`
    Sets the relay's ContactInfo field.

* `tor_nickname`
  - up to 19 chars long, must contain only the characters [a-zA-Z0-9]
  - all tor instances on a host will get the same nickname

* `tor_ExitRelay` boolean 
  - You will want to set this to True if you want to run exit relays.
  - default: False

* `tor_ExitPolicy`
  - specify your custom exit policy
  - is only relevant if tor_ExitRelay is True
  - default: reduced exit policy (https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy)

* `tor_ports` This var allows you to 
  - change default ports
  - reduce the number of Tor instances created per IP address
  - disable DirPorts by setting them to 0
  - HINT: choose them wisely and *never* change them again ;)

* `tor_alpha` boolean
  * Set to True if you want to run Tor alpha releases.
  * default: False
  * This setting is supported on CentOS and Fedora only.

* `tor_ips`
  * If you want to use only specific IP addresses for Tor.
  * Makes only sense in host_vars context.

* `tor_maxips`
  - Limits the amount of IPs we will use to generate instances on a single host.
  - Indirectly limits the amount of instances we generate per host.
  - If tor_ips is set, tor_maxips has no effect.
  - default: 10

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
section of tor's manual. Set them via 'tor_<name>'.
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

Non OS specific tags:
* install - installs tor but does not start or enable it
* createdir - creates (empty) datadirs only, usefull for migration (requires tor to be installed)
* reconfigure - regenerates torrc files and reloads tor (requires previously configured tor instances)

Misc tags:
* freebsdkern - takes care of setting kern.ipc.somaxconn and kern.ipc.nmbclusters

So if you have a big family and you are about to add an OpenBSD host you typically
make two steps

1. install the new server by running only against the new server (-l) and only the os specific tag (openbsd)
`ansible-playbook tor.yml -l newserver --tags openbsd`

2. then reconfigure all servers (MyFamily) by running the 'reconfigure' tag against all servers.
Running the 'reconfigure' tag without a full or os specific run before that, will fail because 'reconfigure' requires old torrc files to be present.
`ansible-playbook tor.yml --tags reconfigure`


Playbook Example II: alpha exit relays with custom ports
-------------------------------------------------------------
Lets run exit relays (using the restricted exit policy)
on the alpha branch with custom well known ports.

```yml
---

- hosts: relays
  vars:
    tor_alpha: True
    tor_ExitRelay: True
    tor_ports:
     - { orport: 22, dirport: 80}
     - { orport: 443, dirport: 8080}
  roles:
   - ansible-relayor
```

Security Considerations
------------------------
This role explicitly specifies sudo for every task that requires it
(most of them). There is no need to run the entire role or playbook with
--sudo/-s. 

This role takes input from every server it is run against
and incorporates that into every torrc it generates.
This opens an attack vector for an adversary that took over
a single tor server in your group of servers. To limit the abilities
of an attacker in such a position we try to validate the input (fingerprints)
before including them in torrc files. 

Reporting Security Bugs
-----------------------

Feel free to submit them in the public issue tracker,
or if you like via GPG encrypted email.

Origins
-------
This is a fork of https://github.com/david415/ansible-tor
(for the main differences see the initial commit message)
