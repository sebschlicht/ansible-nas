ANSIBLE_VAULT_PASSWORD_FILE = .vault_pass
ANSIBLE_INVENTORY = ko
EASYRSA_DIR = ca
EASYRSA_PKI_DIR = ${EASYRSA_DIR}/pki
CA_TRANSFER_FILES_DIR = files-ca-transit
REQUESTS_ARCHIVE = ${CA_TRANSFER_FILES_DIR}/requests.zip
CERTS_ARCHIVE = ${CA_TRANSFER_FILES_DIR}/certificates.zip

koblenz:
	@$(eval ANSIBLE_INVENTORY=ko)

bendorf:
	@$(eval ANSIBLE_INVENTORY=bendorf)

openvpn-initialize:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags openvpn-init

openvpn-pack-requests:
	@./openvpn-helper.sh pack-requests

openvpn-distribute-server-files:
	@./openvpn-helper.sh copy-files "${ANSIBLE_VAULT_PASSWORD_FILE}"

openvpn-extract-certificates:
	@[ -f "${CERTS_ARCHIVE}" ] || ( echo 'Certificates archive path invalid or unknown, use `make openvpn-extract-certificates CERTS_ARCHIVE=/path/to/certificates.zip`'; exit 2 )
	@./openvpn-helper.sh extract-certificates "${CERTS_ARCHIVE}"

openvpn-configure:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags openvpn-config

# for usage on a secure, offline CA device
openvpn-ca-init: export EASYRSA_PKI = ${EASYRSA_PKI_DIR}
openvpn-ca-init:
	@echo '[WARN] Ensure to have your certificate authority reside on an offline device, due to security!'
	@[ ! -f "${EASYRSA_PKI}/ca.crt" ] || ( echo 'CA is already fully initialized'; exit 3 )
	@dpkg -s easy-rsa | grep Status | grep -q installed || sudo apt install -y easy-rsa
	make-cadir "${EASYRSA_DIR}"
	"${EASYRSA_DIR}/easyrsa" init-pki
	@dd if=/dev/urandom of="${EASYRSA_PKI}/.rnd" bs=256 count=1
	"${EASYRSA_DIR}/easyrsa" build-ca
openvpn-ca-sign-requests:
	@[ -f "${REQUESTS_ARCHIVE}" ] || ( echo 'Requests archive path unknown, use `make openvpn-ca-sign-requests REQUESTS_ARCHIVE=/path/to/requests.zip`'; exit 2 )
	@./openvpn-helper.sh sign-requests "${REQUESTS_ARCHIVE}"

setup-all:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml

setup-base-without-mount:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags os,sshd,ufw,userdata

setup-base-with-mount:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags os,sshd,ufw,mount,userdata

setup-auto-upgrade:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags auto-upgrade

setup-backup:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags backup

setup-dynv6:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags ddns

setup-minidlna:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags dlna

setup-mumble:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags mumble

setup-samba:
	ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} -i inventories/${ANSIBLE_INVENTORY} setup.yml --tags samba

vault-edit-global-nas:
	ansible-vault edit --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} group_vars/nas/vault

vault-edit-inventory-nas:
	ansible-vault edit --vault-password-file=${ANSIBLE_VAULT_PASSWORD_FILE} inventories/${ANSIBLE_INVENTORY}/group_vars/nas/vault
