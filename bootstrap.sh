#!/bin/bash

# This script is run 

set -euo pipefail

# Whoops, things are very strangely broken without this!
export PATH

# We occasionally reach out to the internet, which requires some idea of what time it is.
/sbin/fake-hwclock load force
echo "Current date: $(date)"

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Determine the user we usually run as
export CONFIG_NAME="${CONFIG_NAME}"
export USER="$(id -nu 1000)"
export HOME="/home/${USER}"

# Disable `userconfig.service`
systemctl disable userconfig.service

# Enable `/data` expansion automatically
systemctl enable grow_data_partition.service
chown "${USER}:${USER}" -R /data

# Equivalent of `loginctl enable-linger ${USER}`
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/${USER}

# Set up wireguard
if [[ -f "${SCRIPT_DIR}/config/wg0.conf" ]]; then
	echo "Setting up wireguard..."
	mkdir -p /etc/wireguard
	cp "${SCRIPT_DIR}/config/wg0.conf" /etc/wireguard/wg0.conf
	systemctl enable wg-quick@wg0.service
fi

# Embed my SSH keys
mkdir -p "${HOME}/.ssh"
curl -L "https://github.com/staticfloat.keys" >> "${HOME}/.ssh/authorized_keys"
chmod 0600 "${HOME}/.ssh/authorized_keys"
chmod 0700 "${HOME}/.ssh"
chown "${USER}:${USER}" -R "${HOME}"

if [[ -f "${SCRIPT_DIR}/config/hostname" ]]; then
    HOSTNAME="$(cat "${SCRIPT_DIR}/config/hostname")"
    echo "Setting hostname to ${HOSTNAME}"
    echo "${HOSTNAME}" > /etc/hostname
    sed -i /etc/hosts -e "s/panopticon/${HOSTNAME}/g"
    hostname "${HOSTNAME}"
fi

# We always use static DNS, since we don't want `resolv.conf` auto-generated:
cat >/etc/resolv.conf <<-EOF
search local
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 4.4.4.4
nameserver 1.1.1.1
EOF

# Disable annoying SSH banners
rm -f /etc/profile.d/wifi-check.sh

rm -f "${SCRIPT_DIR}/config/sshd_banner"
if [[ -f "${SCRIPT_DIR}/config/sshd_banner" ]]; then
    cp "${SCRIPT_DIR}/config/sshd_banner" /usr/share/userconf-pi/sshd_banner
fi

# Run the config's `run.sh`
bash "${SCRIPT_DIR}/config/run.sh"
