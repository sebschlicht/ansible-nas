#!/bin/bash
#
# Part of the Ansible NAS setup repository at
# https://github.com/sebschlicht/ansible-nas
#
# Check its documentation on how to setup OpenVPN with this script.
#
EASYRSA_DIR=ca
EASYRSA_BIN="$EASYRSA_DIR/easyrsa"
EASYRSA_PKI_DIR="$EASYRSA_DIR/pki"

TRANSIT_DIR=files-ca-transit
CLIENT_DISTRIBUTION_TRANSIT_DIR="$TRANSIT_DIR/to-clients"
SERVER_TA_KEY_PATH="$CLIENT_DISTRIBUTION_TRANSIT_DIR/ta.key"

REQUESTS_DIR_NAME=requests
REQUESTS_DIR="$TRANSIT_DIR/$REQUESTS_DIR_NAME"
REQUESTS_ARCHIVE_NAME=requests.zip
REQUESTS_ARCHIVE_PATH="$TRANSIT_DIR/$REQUESTS_ARCHIVE_NAME"

CERTS_DIR="$TRANSIT_DIR/certificates"
CERTS_ARCHIVE_NAME=certificates.zip
CERTS_ARCHIVE_PATH="$TRANSIT_DIR/$CERTS_ARCHIVE_NAME"

ANSIBLE_FILES_DIR=files

fc_pack_requests() {
    rm -f "$REQUESTS_ARCHIVE_PATH"
    pushd "$TRANSIT_DIR" >/dev/null
    zip -Tq -r "$REQUESTS_ARCHIVE_NAME" "$REQUESTS_DIR_NAME"
    popd >/dev/null
    rm -rf "$REQUESTS_DIR"
}

fc_sign_requests() {
    local request_type="$1"
    for inventory_dir in "$REQUESTS_DIR"/*; do
        if [ ! -d "$inventory_dir" ]; then
            continue
        fi
        local inventory_name="$(basename -- "$inventory_dir")"
        local cert_id="$request_type-$inventory_name"
        local certificate_request_path="$inventory_dir/$request_type.req"
        local inventory_certs_dir="$CERTS_DIR/$inventory_name/openvpn"

        mkdir -p "$inventory_certs_dir"
        cp "$EASYRSA_PKI_DIR/ca.crt" "$inventory_certs_dir/ca.crt"

        if [ -f "$certificate_request_path" ]; then
            "$EASYRSA_BIN" --pki-dir="$EASYRSA_PKI_DIR" import-req "$certificate_request_path" "$cert_id"
            "$EASYRSA_BIN" --pki-dir="$EASYRSA_PKI_DIR" --batch sign-req "$request_type" "$cert_id"
            cp "$EASYRSA_PKI_DIR/issued/$cert_id.crt" "$inventory_certs_dir/$request_type.crt"
        fi
    done
}

fc_sign_and_pack_certificates() {
    unzip -q "$1" -d "$TRANSIT_DIR"
    rm -f "$CERTS_ARCHIVE_PATH"

    rm -f "$EASYRSA_PKI_DIR/reqs"/*
    fc_sign_requests server
    fc_sign_requests client

    pushd "$CERTS_DIR" >/dev/null
    zip -Tq -r "../$CERTS_ARCHIVE_NAME" .
    popd >/dev/null
}

fc_extract_certificates() {
    unzip -q "$1" -d "$ANSIBLE_FILES_DIR"
}

fc_copy_distribution_files() {
    local vault_password_file="$1"
    if [ -f "$SERVER_TA_KEY_PATH" ]; then
        if ! head -1 "$SERVER_TA_KEY_PATH" | grep -q '^\$ANSIBLE_VAULT;1.1;AES256$'; then
            ansible-vault encrypt --vault-password-file="$vault_password_file" "$SERVER_TA_KEY_PATH" 1>/dev/null
        fi
    fi

    for inventory_dir in "$ANSIBLE_FILES_DIR"/*; do
        local inventory_openvpn_files_dir="$inventory_dir/openvpn"
        if [ -f "$inventory_openvpn_files_dir/client.crt" ]; then
            cp "$TRANSIT_DIR/to-clients"/* "$inventory_openvpn_files_dir/"
        fi
    done
}

if [ "$1" = 'pack-requests' ]; then
    fc_pack_requests
elif [ "$1" = 'sign-requests' ]; then
    fc_sign_and_pack_certificates "$2"
elif [ "$1" = 'extract-certificates' ]; then
    fc_extract_certificates "$2"
elif [ "$1" = 'copy-files' ]; then
    fc_copy_distribution_files "$2"
fi
