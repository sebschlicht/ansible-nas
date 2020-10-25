# NAS Playbook

This repository contains Ansible playbooks and roles to transform your RaspberryPi (or another system based on Debian/Ubuntu) into a NAS.
At the very heart, the term NAS refers to an OpenSSH server to securely backup user data to:

* secure OpenSSH server to automatically backup files
  * encrypted file transfer (SSH)
  * key-based authentication (e.g. [backupnas](https://github.com/sebschlicht/backupnas) for UNIX clients, [FreeFileSync](https://freefilesync.org/) for Windows clients)
  * with all users created automatically and their SSH keys in place

However, this playbook supports a variety of services (e.g. Samba, DLNA, Nextcloud) that can be plugged in by specifying one or more [tags](#tags).

While most configuration options are hard-coded to fit the recommendations for the respective service, you can configure (among others):

* the users, their SSH keys and passwords (individually for all services)
* the storage locations (for SSH-based backups and the Nextcloud instance)
* which folders to expose via DLNA
* the mail account to use for notifications

## Tags

* `mount`: automatically mount an external hard drive to extent storage capabilities
  * all user data will be stored on this external drive
* `cloud`: [Nextcloud](https://nextcloud.com/) server to upload and share files in a personal cloud
  * encrypted file transfer (HTTPS)
    * automatically renewed SSL certificates (Let's Encrypt)
    * Mozilla's intermediate SSL configuration for secure but still largely compatible communication
  * automatically installed and configured
    * including all required components and users
    * applying performance recommendations and hardening
* `samba`: [Samba](https://www.samba.org/) server to access stored files from any desktop or mobile device
  * password authentication for users, password-free public shares for guests
  * *unencrypted file transfer*
* `dlna`: [DLNA](https://en.wikipedia.org/wiki/Digital_Living_Network_Alliance) server to access stored media files from smartTVs etc.
  * automatically discover and play videos and/or music
  * *unencrypted file transfer*
* `ddns`: dynamic DNS update client
  * hourly (and when rebooted) reports the device's IP address to DynV6, to have it accessible via DNS (e.g. my-nas-device.dynv6.net)
* `auto-upgrade`: keep installed software up-to-date
* `ufw`: firewall to restrict incoming traffic to the selected services (i.e. specified tags)

## Usage

In order to apply this playbook to one of your machines, there are basically two steps required:

1. [configure the inventory](#inventory-configuration) to your needs
1. Run the playbook:
   1. Use the named [tags](#tags) to precisely choose which services to install, e.g. only Samba and Nextcloud:

       ansible-playbook -i inventories/custom setup.yml --tags samba,nextcloud

   1. Omit tags to install all available services:

       ansible-playbook -i inventories/custom setup.yml

## Inventory Configuration

The inventory `inventories/custom` is intended to be used when running this playbook and can be fully adapted to your needs.

Within this inventory, you *must* adapt the first two files and *should* make use of the third, though it's not technically required:

Path                       | Defines
---------------------------|------------------------------------------------------
`hosts.yml`                | [hosts](#hosts) that the playbook is running against
`group_vars/nas/vars.yml`  | [variables](#variables) that are used in the playbook
`group_vars/nas/vault.yml` | [vault](#vault) for credential variables

### Hosts

The hosts file `hosts.yml` defines the machine that will be configured by this playbook.

Simply edit the file and place your machine (e.g. `pi3`) as a NAS host:

    all:
      children:
        nas:
          hosts:
            pi3

### Variables

The variables of this playbook are defined in the YAML file `group_vars/nas/vars.yml`.
They are loosely structured by the different features that this playbook offers and should be quite self-explanatory already.

The table below lists which variables are available for each feature.
You only need to care about the variables of features that you are going to install.

Role | Variable | Description
---- | -------- | -----------
*    | `setup_user`            | remote user to login and use for the setup process
*    | `nas.hostname`          | desired hostname of the NAS
*    | `nas.user.name`         | name of the artificial NAS user that is used for service tasks (will be created if missing)
*    | `sshd.allow_users`      | list of users that are allowed to SSH into the NAS, besides the individual users
*    | `sshd.enable_password_authentication` | flag to enable the password-based authentication for SSH clients (default: `false`). strongly discouraged, specify authorized keys per user instead
*    | `users`                 | list of individual users, each having a user `name`, an `initial_password` hash, a `nextcloud_password` and a `samba_password` (if the respective features are used). you may also specify a `backup_folder_name` (defaults to username) and additional group assignments (`groups`) on the OS level. you may as well specify a list of `authorized_keys` for passwordless SSH access
mount | `mount_base_dir`       | directory for mount points of external storage devices
mount | `mounts.primary.*`     | primary mount point that all user data will be stored at, by default. mounted via the `uuid` field. use `fstype` and `opts` to specify the filesystem and options of the mount (defaults fit NTFS-formatted drives)
mount | `mounts.secondary.*`   | optional secondary mount point, that the primary mount point will be mirrored to (same configuration options available)
auto-upgrade, cloud | `mailing.*`      | `server`, `user` name, `address`, `password` and `sender_name` for the mail account to be used for sending mails (e.g. notifications, password resets)
auto-upgrade, cloud | `mail_recipient` | recipient for administrator mails (e.g. performed upgrades)
cloud | `nas.domain`           | public domain to access the machine
cloud | `dynv6.token`           | token to update the current IP address of the NAS domain on DynV6
samba | `samba.internal_shares` | internal Samba shares, each having a `name` and a `path`, that are accessible with any account
samba | `samba.public_shares`   | public Samba shares, each having a `name` and a `path`, that are accessible even without an account
dlna  | `minidlna.*`            | `display_name` to be shown in client devices, `directories` to list paths that should be accessible for clients

### Vault

An Ansible vault is a place for storing credentials and sensitive information alike in an encrypted manner. Please refer to the [official documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html) if you want to learn how to create and use one.

Using a vault is mandatory if you want to have your credentials under version control, for example.
For simplicity, you may choose to not use a vault and assign your credentials to the variables of this playbook directly.
However, you should always strongly consider to use a vault for security reasons.

## Port Forwarding

> **_NOTE:_** Instead of forwarding the relevant ports from your router to the NAS, you should strongly consider to use a VPN to avoid any unencrypted file transfer in the internet.

The NAS runs different services that operate on various ports.
When operating the NAS behind a router (i.e. firewall), these ports have to be accessible.

In case you insist on using port forwarding, the following ports are used by the respective services:

Service | TCP      | UDP
--------|----------|---------
Samba   | 139, 445 | 137, 138
OpenSSH | 22       |

These are the default ports.
Strongly-consider to expose the services at non-default ports to prevent the load and risk that is caused by bots.
