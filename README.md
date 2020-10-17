# NAS Playbook

This repository contains an Ansible playbook to transform your RaspberryPi 3 (and most UNIX-based systems like Ubuntu) into a NAS, supporting

* backups
  * encrypted file transfer (SSH)
  * key-based authentication (e.g. [backupnas](https://github.com/sebschlicht/backupnas) for UNIX clients, [FreeFileSync](https://freefilesync.org/) for Windows clients)
  * on a per-user basis
  * potentially mirrored to a second location
* flexible [Samba](https://www.samba.org/) shares for maximum compatibility
  * read/write access for UNIX-based, Windows and mobile clients
  * password authentication for users
  * password-free public shares for guests
  * *unencrypted file transfer*
* [DLNA](https://en.wikipedia.org/wiki/Digital_Living_Network_Alliance) access for your smartTV (among many)
  * play videos and/or music on UPnP devices
  * automatic discovery for all compatible devices
  * *unencrypted file transfer* (read-only)

## Usage

In order to apply this playbook to one of your machines, there are basically two steps required:

1. [configure the inventory](#inventory-configuration) to your needs
1. run the playbook (use [tags](#tags) to install only specific components)

       ansible-playbook -i inventories/custom nas.yml

## Tags

This playbook consists of numerous roles that each setup a specific part of your NAS.
While some roles form the basis of a NAS, others are entirely optional and provide additional features.
Thus, most roles map to tags that allow to opt-in the respective feature.

For example, the following run would only setup a rudimentary NAS on your machine:

    ansible-playbook -i inventories/custom --tags nas nas.yml

If tags are ommitted, however, all roles will be used and hence all features will be installed.

The following tags are available:

* `nas`
  
  The basic role of this playbook.

  It creates the desired users that other roles depend on and mounts the specified devices in the configured locations to serve as a storage for the NAS.

  *Note*: For maximum compatiblity and convenience, these devices are assumed to be NTFS-formatted.

* `mailing`

  Configures a mail account for the `root` user, to allow for mail-based notifications.

* `auto-upgrade`

  Configures unattended upgrades, using mail-based notifications.

  Thus, this tag can only be used together with  `mailing`.

* `sshd`

  Hardens the SSH server and configures passwordless SSH access to the target machine for all NAS users.
  You can configure to also allow password-based authentication, if you need to.

* `dyndns`

  Configures the NAS to automatically update the dynamic DNS record.
  In this case, the update script of DynV6 is placed on the NAS and scheduled to report your public IP address to DynV6 whenever the system reboots or an hour has passed.

  *Note*: Due to the script's implementation, the IP address will not be reported until it has actually changed.

* `dlna`

  Installs and configures a miniDLNA server to serve DLNA clients such as SmartTVs.

  Use the configuration to specify the media folders with videos/music/pictures that should be made available to clients.

* `smb`

  Installs and configures a Samba server on the NAS, to allow users to access their backup folders (and others) from any device.

  Use the configuration to specify a Samba password for each NAS user.

* `cloud`

  Installs and configures a Nextcloud instance of the NAS, to allow users to store files in a private cloud.

  Use the configuration to specify a Nextcloud password for each NAS user.

* `firewall`

  Installs the firewall `ufw` to protect your NAS against bots and other threats.

  *Note*: Per default, all outgoing traffic is allowed and all incoming traffic is blocked.
  Only the ports of features that are installed by this script will be accessible from outside.


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

Variable | Description
-------- | -----------
`setup_user`            | remote user to login and use for the setup process
`nas.hostname`          | desired hostname of the NAS
`nas.domain`            | public domain for the NAS device (e.g. when hosting a Nextcloud)
`nas.user.name`         | name of the artificial NAS user that is used for service tasks (will be created if missing)
`nas.mount_base_dir`    | directory for mount points of external storage devices
`nas.mounts.primary`    | primary location of the NAS data, specified as a folder `name` within the mount point directory. if a `uuid` is specified, the respective device will be mounted to that folder. use `fstype` and `opts` to specify the filesystem and options of the mount (defaults fit NTFS-formatted drives)
`nas.mounts.secondary`  | optional secondary location of the NAS data, that the primary location will be mirrored to
`mailing.*`             | `server`, `user` name, `address`, `password` and `sender_name` for the mail account to be used for sending notifications
`unattended_upgrades.notification_mail_recipient` | recipient for summary mails of performed unattended upgrades
`sshd.allow_users`      | list of users that are allowed to SSH into the NAS, besides the individual users
`sshd.enable_password_authentication` | flag to enable password-based authentication for SSH clients (default: `false`)
`users`                 | list of individual NAS users, each having a user `name`, an `initial_password` and a `samba.password` (if this feature is used). you may also specify a `backup_folder_name` (defaults to username) and additional group assignments (`groups`). you may as well specify a list of `authorized_keys` for passwordless SSH access. if no keys have been specified, the user won't be able to connect via SSH unless the password authentication is enabled
`dynv6.token`           | token to update the current IP address of the NAS domain on DynV6
`minidlna.*`            | `display_name` to be shown in client devices, `directories` to list paths that should be accessible for clients
`samba.internal_shares` | internal Samba shares, each having a `name` and a `path`, that are accessible with any account
`samba.public_shares`   | public Samba shares, each having a `name` and a `path`, that are accessible even without an account
`running_in_container`  | flag to disable unsupported operations when running inside a container (e.g. Docker)

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
