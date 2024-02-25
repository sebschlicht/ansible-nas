#!/bin/bash
#
# This is a wrapper script to perform backups using (restic)[https://restic.net/] in a setup with two networks (e.g. side-to-side VPN).
# Its purpose is to create backups and store them on machines in both networks, ideally geo-spread.
#
# The backup process consists of three steps:
# * back up to a local (network) repository
# * verify the integrity of the local repository
# * push all local backups to a remote repository
# The process in aborted and a notification (including the log file), should any of the steps fail.
#
# Dependencies:
# * mail transfer agent installed and configured
#
PROGRAM_NAME='restic-wrapper'
QUIET=false

#################################
# variable initialization section
#################################
OS_USER="$USER"
BACKUP_SOURCE_DIR=
LOG_FILE_DIR=.
LOCAL_REPOSITORY=
REMOTE_REPOSITORY=
PASSWORD_FILE=
EXCLUDE_FILE=/dev/null
NOTIFICATION_ADDRESS=

###################
# constants section
###################
LOCAL_BACKUP_FAILED='[ERR] Backup failed'
INTEGRITY_LOSS='[ERR] Backup integrity failure'
PUSHING_BACKUP_FAILED='[WARN] Creating a copy of the backup failed'
BACKUP_SUCCEEDED='[INFO] Backup created'
SFTP_COMMAND="ssh -F '{{ nas_ssh_dir }}/config' {{ restic_ssh_config_entry }} -s sftp"

# Prints the usage of the script in case of using the help command.
printUsage() {
  echo 'Usage: '"$PROGRAM_NAME"' [OPTIONS] BACKUP_SOURCE_DIRECTORY'
  echo
  echo 'Restic wrapper to add a snapshot in a repository, verify the repositories integrity and push all its snapshots to another.'
  echo
  echo 'Options:'
  echo '-h, --help	Display this help message and exit.'
  echo '-u, --user Operating system user to instrument. Defaults to $USER.'
  echo '-r, --local-repository Restic repository in the local network'
  echo '-b, --remote-repository Restic repository in the remote network'
  echo '-p, --password-file  Restic password file'
  echo '-l, --log-file-dir Path to the log file directory'
  echo '-m, --notification-mail-address Mail address to send notifications to'
}

# Echoes an error message to stderr.
fc_error() {
  if [ "$QUIET" = false ]; then
    echo >&2 -e "[ERROR] $1"
  fi
}
# Echoes a warning to stderr.
fc_warn() {
  if [ "$QUIET" = false ]; then
    echo >&2 -e "[WARN] $1"
  fi
}
# Echoes an info message to stdout.
fc_info() {
  if [ "$QUIET" = false ]; then
    echo -e "[INFO] $1"
  fi
}

# Parses the startup arguments into variables.
parseArguments() {
  while [[ $# > 0 ]]; do
    key="$1"
    case $key in
    # help
    -h | --help)
      printUsage
      exit 0
      ;;
    # quiet mode
    -q | --quiet)
      QUIET=true
      ;;
    # user
    -u | --user)
      shift
      OS_USER="$1"
      ;;
    # local repository
    -r | --local-repository)
      shift
      LOCAL_REPOSITORY="$1"
      ;;
    # remote repository
    -b | --remote-repository)
      shift
      REMOTE_REPOSITORY="$1"
      ;;
    # password file
    -p | --password-file)
      shift
      PASSWORD_FILE="$1"
      ;;
    # exclude file
    -e | --exclude-file)
      shift
      EXCLUDE_FILE="$1"
      ;;
    # log file directory
    -l | --log-file-dir)
      shift
      LOG_FILE_DIR="$1"
      ;;
    # notification mail address
    -m | --notification-mail-address)
      shift
      NOTIFICATION_ADDRESS="$1"
      ;;
    # unknown option
    -*)
      fc_error "Unknown option '$key'!"
      return 2
      ;;
    # parameter
    *)
      if ! handleParameter "$1"; then
        fc_error 'Too many arguments!'
        return 2
      fi
      ;;
    esac
    shift
  done

  # check for valid number of parameters
  if [ -z "$BACKUP_SOURCE_DIR" ]; then
    fc_error 'Too few arguments!'
    return 2
  fi

  ##########################
  # check parameter validity
  ##########################
  if [ -z "$LOCAL_REPOSITORY" ]; then
    fc_error 'No local backup repository specified!'
    return 2
  fi
  if [ -z "$REMOTE_REPOSITORY" ]; then
    fc_error 'No remote backup repository specified!'
    return 2
  fi
  if [ -z "$PASSWORD_FILE" ]; then
    fc_error 'No password file specified!'
    return 2
  fi
}

# Handles the parameters (arguments that aren't an option) and checks if their count is valid.
handleParameter() {
  # 1. parameter: backup source directory
  if [ -z "$BACKUP_SOURCE_DIR" ]; then
    BACKUP_SOURCE_DIR="${1%/}"
  else
    # too many parameters
    return 1
  fi
}

##############################
# main script function section
##############################
fc_unlock_repository() {
  restic unlock -q -r "$1" -p "$PASSWORD_FILE"
}
fc_init_repository() {
  if ! fc_unlock_repository "$1"; then
    fc_info "Initializing repository '$1'."
    restic init -o sftp.command="$SFTP_COMMAND" -r "$1" -p "$PASSWORD_FILE"
  fi
}
fc_init_local_repository() {
  sudo chown -R "$OS_USER:" "$LOCAL_REPOSITORY"
  if ! fc_init_repository "$LOCAL_REPOSITORY"; then
    fc_notify "$LOCAL_BACKUP_FAILED" "Initializing local repository '$LOCAL_REPOSITORY' failed!"
    return 1
  fi
}
fc_init_remote_repository() {
  if ! fc_init_repository "$REMOTE_REPOSITORY"; then
    fc_notify "$PUSHING_BACKUP_FAILED" "Initializing remote repository '$REMOTE_REPOSITORY' failed!"
    return 1
  fi
}
fc_create_local_backup() {
  local rc=0
  fc_info "Backing up '$BACKUP_SOURCE_DIR' to repository '$LOCAL_REPOSITORY'."
  if ! sudo restic backup -r "$LOCAL_REPOSITORY" -p "$PASSWORD_FILE" --exclude-file "$EXCLUDE_FILE" "$BACKUP_SOURCE_DIR"; then
    rc=1
    fc_notify "$LOCAL_BACKUP_FAILED" "Creating the local backup for '$BACKUP_SOURCE_DIR' failed!"
  fi
  sudo chown -R "$OS_USER:" "$LOCAL_REPOSITORY"
  return "$rc"
}
fc_check_local_repository() {
  fc_info "Verifying the integrity of backups in repository '$LOCAL_REPOSITORY'."
  if ! restic check -q -r "$LOCAL_REPOSITORY" -p "$PASSWORD_FILE"; then
    fc_notify "$INTEGRITY_LOSS" "Integrity loss in backup repository '$LOCAL_REPOSITORY'!"
    return 1
  fi
}
fc_push_local_backups_to_remote() {
  fc_info "Pushing the backup to '$REMOTE_REPOSITORY'."
  if ! restic copy -o sftp.command="$SFTP_COMMAND" -q -r "$REMOTE_REPOSITORY" -p "$PASSWORD_FILE" --from-repo "$LOCAL_REPOSITORY" --from-password-file "$PASSWORD_FILE"; then
    fc_notify "$PUSHING_BACKUP_FAILED" "Pushing the local backups of '$LOCAL_REPOSITORY' to '$REMOTE_REPOSITORY' failed!"
    return 1
  fi
}
fc_notify() {
  if [ -n "$NOTIFICATION_ADDRESS" ]; then
    local mail_subject="$1"
    local mail_introduction="$2"
    if ! {
      echo "$mail_introduction"
      echo -e "\nLog:\n"
      cat "$LOG_FILE"
    } | mail -s "$mail_subject" -- "$NOTIFICATION_ADDRESS"; then
      fc_error 'Failed to notify the user!'
    fi
  fi
}

#############
# entry point
#############
parseArguments "$@"
SUCCESS=$?
if [ "$SUCCESS" -ne 0 ]; then
  fc_error "Use the '-h' switch for help."
  exit "$SUCCESS"
fi

# create log file directory
if [ ! -d "$LOG_FILE_DIR" ]; then
  mkdir -p "$LOG_FILE_DIR"
fi
LOG_FILE="$LOG_FILE_DIR/restic-$(date --iso-8601).log"

echo >>"$LOG_FILE" 2>&1
echo '---------------' >>"$LOG_FILE" 2>&1
date >>"$LOG_FILE" 2>&1

# perform local backup; then copy it to the remote location
fc_init_local_repository >>"$LOG_FILE" 2>&1 &&
  fc_create_local_backup >>"$LOG_FILE" 2>&1 &&
  fc_check_local_repository >>"$LOG_FILE" 2>&1 &&
  fc_init_remote_repository >>"$LOG_FILE" 2>&1 &&
  fc_push_local_backups_to_remote >>"$LOG_FILE" 2>&1 &&
  fc_info 'Backup has been created successfully.' >>"$LOG_FILE" 2>&1 &&
  fc_notify "$BACKUP_SUCCEEDED" "Backup has been created successfully."
