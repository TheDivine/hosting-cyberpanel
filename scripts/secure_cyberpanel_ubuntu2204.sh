#!/usr/bin/env bash
set -euo pipefail

# Minimal hardening + CyberPanel installer helper for Ubuntu 22.04
# Usage: sudo ./secure_cyberpanel_ubuntu2204.sh <fqdn> <ssh_port> <admin_user>
# Example: sudo ./secure_cyberpanel_ubuntu2204.sh panel.example.com 22 sysadmin

FQDN=${1:-}
SSH_PORT=${2:-22}
ADMIN_USER=${3:-sysadmin}

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (use sudo)." >&2
  exit 1
fi

if [[ -z "$FQDN" ]]; then
  echo "FQDN argument required. Example: panel.example.com" >&2
  exit 1
fi

echo "[+] Setting hostname to $FQDN"
hostnamectl set-hostname "$FQDN"

echo "[+] Updating packages"
apt-get update -y
apt-get install -y curl wget ufw fail2ban unattended-upgrades chrony rsyslog

echo "[+] Enabling unattended upgrades"
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
  "origin=Ubuntu,codename=${distro_codename}-security,label=Ubuntu";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:30";
EOF
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "[+] Creating admin user $ADMIN_USER (no password)"
id -u "$ADMIN_USER" >/dev/null 2>&1 || adduser --disabled-password --gecos "" "$ADMIN_USER"
usermod -aG sudo "$ADMIN_USER"
install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" \
  "/home/$ADMIN_USER/.ssh"
echo "Place your SSH public key in /home/$ADMIN_USER/.ssh/authorized_keys before logging out!"
touch "/home/$ADMIN_USER/.ssh/authorized_keys"
chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"

echo "[+] Hardening SSH"
sed -ri "s/^#?Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -ri "s/^#?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart ssh

echo "[+] Configuring UFW"
ufw default deny incoming || true
ufw default allow outgoing || true
ufw allow ${SSH_PORT}/tcp || true
ufw allow 22/tcp || true # avoid lockout while changing ports
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw allow 8090/tcp || true # CyberPanel
ufw allow 7080/tcp || true # OLS admin
yes | ufw enable || true

echo "[+] Enabling Fail2Ban"
cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ${SSH_PORT}
filter  = sshd
logpath = /var/log/auth.log
backend = systemd
EOF
systemctl restart fail2ban

echo "[+] Ensuring time sync"
systemctl enable --now chrony

echo "[+] Downloading CyberPanel installer to /root/cyberpanel_install.sh"
curl -fsSL https://cyberpanel.net/install.sh -o /root/cyberpanel_install.sh
chmod +x /root/cyberpanel_install.sh

cat <<'EONOTE'

Next steps:
- Run: bash /root/cyberpanel_install.sh
- Choose: Full install, OpenLiteSpeed, local MariaDB, and (optionally) Memcached/Redis.
- Set a strong admin password when prompted.
- Once complete, visit: https://<your-ip-or-fqdn>:8090/

EONOTE

echo "[+] Done. Verify SSH access on port ${SSH_PORT} before closing your current session."

