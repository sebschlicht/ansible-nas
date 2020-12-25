# NAS Playbook

This repository contains Ansible playbooks and roles to transform your RaspberryPi (or another system based on Debian/Ubuntu) into a NAS.
At the very heart, the term NAS refers to a machine with:

* a secure OpenSSH server to automatically backup files
  * encrypted file transfer (SSH)
  * key-based authentication (e.g. [backupnas](https://github.com/sebschlicht/backupnas) for UNIX clients, [FreeFileSync](https://freefilesync.org/) for Windows clients)
  * with all users created and configured automatically
* `fail2ban` enabled

However, this playbook supports a variety of services (e.g. Samba, DLNA, Nextcloud) that can be plugged in by specifying one or more [tags](#tags).

While most configuration options are hard-coded to fit the recommendations for the respective service, you can configure (among others):

* users, their SSH keys and passwords
* storage locations
* folders accessible via DLNA
* mail account used for system notifications

## Tags

* `mount`: automatically mount external hard drives to store user data/backups at
* `backup`: schedule [restic](https://restic.net/) to securely backup the entire user data (at 2 a.m.) to a local directory / external hard drive or remote location (SFTP)
* `cloud`: [Nextcloud](https://nextcloud.com/) server to upload and share files in a personal cloud
  * encrypted file transfer (HTTPS)
    * automatically renewed SSL certificates (Let's Encrypt)
    * Mozilla's intermediate SSL configuration (secure but aiming for compatibility)
  * fully installed and configured
    * including all required components and users
    * applying performance recommendations and hardening
* `samba`: [Samba](https://www.samba.org/) server to access stored files from any desktop or mobile device in your network
  * password authentication for users, optional guest shares
  * *unencrypted file transfer*
* `dlna`: [DLNA](https://en.wikipedia.org/wiki/Digital_Living_Network_Alliance) server to access stored media files from a SmartTV etc.
  * automatically discover and play videos and/or music
  * *unencrypted file transfer*
* `mumble`: [Mumble](https://www.mumble.info/) server (aka. Murmur) for low-latency voice chats
* `ddns`: dynamic DNS update client
  * hourly (and on reboot) reports the device's IP address to DynV6, to have it accessible via a domain
* `auto-upgrade`: keep installed software up-to-date
* `ufw`: firewall to restrict incoming traffic to the selected services (i.e. specified tags)
* `openvpn-config`: make the device an [OpenVPN client/server](#openvpn-setup) to form a network with another device

## Usage

In order to apply this playbook to one of your machines, there are basically two steps required:

1. [configure the inventory](#inventory-configuration) to your needs
2. Run the playbook, using [tags](#tags) to precisely choose which services to install:

       ansible-playbook -i inventories/example setup.yml --tags samba,nextcloud

## Configuration

The configuration consists of
1. global variables at `group_vars/all.yml`
2. an Ansible inventory containing
   1. the address of the remote machine(s) at `hosts.yml`
   2. specific variables at `group_vars/nas/vars.yml`
   3. specific credentials in an [Ansible vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) at `group_vars/nas/vault`
3. files to be copied to the remote machine in the `files` folder

The example inventory at `inventories/example` can be copied and fully adapted to your needs.

The configuration variables are loosely structured by the features that this playbook offers.
If you use tags to selectively enable features, you only have to adapt their variables and may omit others.

Check existing files for available variables and their meaning.

## Scheduled Jobs

| Interval        | Description                 | Active when feature selected |
| --------------- | --------------------------- | ---------------------------- |
| daily at 2 a.m. | backup user data            | backup                       |
| daily at 5 a.m. | rescan miniDLNA directories | dlna                         |

## Port Forwarding

> **_Note:_** Instead of forwarding relevant ports from your router to the NAS, strongly consider using a VPN to avoid any unencrypted file transfer (e.g. Samba) via internet.

The NAS runs different services that operate on various ports.
When operating the NAS behind a router (i.e. firewall), these ports have to be accessible.

In case you insist on using port forwarding, the following ports are used by the respective services:

| Service   | TCP      | UDP      |
| --------- | -------- | -------- |
| Samba     | 139, 445 | 137, 138 |
| OpenSSH   | 22       |
| Nextcloud | 80, 443  |

These are the default ports.
Strongly-consider to expose the services at non-default ports to prevent the load and risk caused by bots.
An execption are the ports 80 and 443, as they are required for the automatic certificate renewal.

## OpenVPN Setup

This repository contains make goals (scripts) to setup a permanent OpenVPN connection between machines with internet access.
One of them acts as the server and thus must be reachable via internet (e.g. dynamic DNS).

### Participants

There are multiple participants in such an OpenVPN setup:

1. certificate authority (CA): owns the key that will sign server and client certificates; may be an offline machine (more secure but requires manually copying files) or your Ansible host
2. server: accepts OpenVPN connections by clients; must be accessible via internet (best to use dynamic DNS)
3. clients: connect to the server; must have internet access to reach the server

### Configuration

Depending on a machine's role (i.e. type of participant), a different property has to be used in the respective Ansible inventory.

Use the `openvpn.server` property in the inventory of the machine that will act as the server and use the `openvpn.client` property for all remaining machines.

### Setup instructions

On the CA machine, initialize the CA, generating key and certificate:

    make openvpn-ca-init

On the Ansible host and for each participant, install OpenVPN, create a certificate request and retrieve it:

    make ANSIBLE_INVENTORY=<inventory> openvpn-initialize

On the Ansible host, pack the retrieved requests:

    make openvpn-pack-requests

>If you use a dedicated offline machine as CA:
>This will create a ZIP file including all retrieved requests at `./files-ca-transit/requests.zip`.
>Copy this archive file to the same relative path on the CA machine now.

On the CA machine, import and sign all requests:

    make openvpn-ca-sign-requests

>If you use a dedicated offline machine as CA:
>This will create a ZIP file including all certificates at `./files-ca-transit/certificates.zip`.
>Copy this archive file to the same relative path on the Ansible host now.

Extract the certificate archive

    make openvpn-extract-certificates

and distribute the certificates to each OpenVPN participant via

    make ANSIBLE_INVENTORY=<inventory> openvpn-configure

This will also start the OpenVPN service on each machine and should leave you with a working OpenVPN setup (wait a few minutes).
