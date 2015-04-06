ansible-relayor
----------------
This is an ansible role for tor relay operators.

The main focus of this role is to automate as many steps as possible for a Tor relay
operator when deploying Tor servers.

Goal:
Adding a new Tor server should be as easy as adding a new host to the inventory,
no further manual configuration should be required.

The main benefits for a relay operator are:
- automatic instance generation (two per available IP address)
- automatic MyFamily management
- automatic Nickname generation (based on a user supplied prefix)
- easily choose between exit relay/non-exit relay mode using a single boolean
- boolean for stable vs. alpha Tor releases

Note: Proper automatic MyFamily handling depends on the inclusion of all relays in the playbook.

THIS ANSIBLE ROLE IS CURRENTLY EXPERIMENTAL!

Dependencies
------------
- systemd on Linux systems
- rcctl on OpenBSD (available since 5.7)
- ansible >= 1.9

Tested on
----------
- Debian Jessie (will not work on wheezy due to systemd requirements)
- CentOS 7
- OpenBSD 5.7
- FreeBSD 10.1

- tor 0.2.5.x / 0.2.6.x

Example Tor Relay Playbook (simple)
------------------------------------

This playbook will use defaults and create two non-exit Tor instances for
every available IP address on the host. 
If the host has 3 IP addresses you will end up with 6 Tor instances (including DirPorts). 
The following default port range is used for listeners:
9001-9004
(if these ports are already in use, things will fail)

```yml
---
- hosts: relays

  tasks:

  - name: create groups based on package manager
    group_by: key="{{ansible_pkg_mgr}}"


- hosts: relays
  gather_facts: False
  roles:
   - ansible-relayor
```

If you run non-debian based systems make sure to put the following files into
your group_vars folder:
```yml
# file: yum
tor_user: _tor
```

```yml
# file: openbsd_pkg
tor_user: _tor
tor_PidDir: /var/tor/pids 
tor_DataDir: /var/tor
```

```yml
# file: pkgng
tor_user: _tor
tor_DataDir: /var/db/tor
tor_ConfDir: /usr/local/etc/tor/enabled
```

Role Variables
--------------
All variables mentioned here are optional.

* `tor_ContactInfo`
    Sets the relay's ContactInfo field.

* `tor_nicknameprefix` 
  - up to 15 chars long, must contain only the characters [a-zA-Z0-9]
  - Will be the first part of your relay's nickname (concatenated with first four chars of the Tor fingerprint)

* `tor_ExitRelay` boolean 
  - You will want to set this to True if you want to run exit relays.
  - Note: This feature does not depend on tor's 'ExitRelay' option recently introduced with tor v0.2.6.3-alpha. 
  - default: False

* `tor_ExitPolicy`
  - specify your custom exit policy
  - is only relevant if tor_ExitRelay is True
  - default: reduced exit policy (https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy)

* `tor_ports` This var allows you to 
  - change default ports (9001-9004)
  - reduce the number of Tor instances created per IP address
  - disable DirPorts by setting them to 0
  - HINT: choose them wisely and *never* change them again ;)

* `tor_alpha` boolean
  * Set to True if you want to run Tor alpha releases.
  * default: False
  * This setting is currently supported on CentOS and FreeBSD only.

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

This role supports most torrc options documented in the 'SERVER OPTIONS'
section of tor's manual. Set them via 'tor_<name>'.
Have a look at templates/torrc if you want to have list of supported
options.

Playbook Example II: alpha exit relays with custom ports and nicknames
-------------------------------------------------------------
Lets run exit relays (using the restricted exit policy)
on the alpha branch with custom well known ports.
All generated relays will have a nickname that starts with
'foo' followed by the first four characters of their fingerprint.

```yml
---
- hosts: relays

  tasks:

  - name: create groups based on package manager
    group_by: key="{{ansible_pkg_mgr}}"


- hosts: relays
  gather_facts: False
  vars:
    tor_alpha: True
    tor_ExitRelay: True
    tor_nicknameprefix: foo
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

Relevant Upstream Bugs
-----------------------
The following upstream bugs are related to this ansible role:
- multi instance startup script
    - debs: https://bugs.torproject.org/14995
- bug in --verify-config : https://bugs.torproject.org/15015

Origins
-------
This is a fork of https://github.com/david415/ansible-tor
(for the main differences see the initial commit message)
