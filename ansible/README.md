CyberPanel Secure Install (Ansible)

Overview
- Installs CyberPanel (OpenLiteSpeed) on Ubuntu 22.04.
- Applies baseline server hardening (SSH, firewall, fail2ban, unattended upgrades, swap, time sync).
- Opens only required ports (80/443/8090 by default). Optional DNS and mail ports are toggleable.
- Adds optional scheduled malware scanning (ClamAV + Linux Malware Detect).

Requirements
- Target: Fresh Ubuntu 22.04 VPS or bare‑metal server with FQDN ready (e.g., panel.example.com)
- Control node: Ansible 2.13+ with SSH access to the target
- If using the automated installer step: Python `pexpect` on the control node (`pip install pexpect`)
- UFW tasks use the `community.general` collection (`ansible-galaxy collection install community.general`)

Quick Start
1) Edit `ansible/inventory.ini` to include your server and SSH details.
2) Edit `ansible/group_vars/all.yml` to set hostname, SSH port, and admin password.
3) Run:

   ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

Notes
- By default, the playbook hardens the server and installs CyberPanel using OpenLiteSpeed.
- Set `enable_dns`/`enable_mail` to true in `group_vars/all.yml` if you plan to run DNS or mail on the panel host; firewall rules will be opened accordingly.
- Installation uses the upstream CyberPanel installer. The playbook attempts to answer prompts via Ansible's `expect` module. If the installer changes prompts, you may need to adjust `responses` patterns in `playbook.yml`.
- After install, visit https://your-fqdn-or-ip:8090/ and log in as `admin` using the password you set.

Security Defaults
- Creates a new sudo user and disables root SSH login and password auth (key-based only).
- Changes SSH port (set via `ssh_port`). Make sure your security groups/firewalls allow it.
- Enables UFW with default deny inbound, allow outbound.
- Enables Fail2Ban for SSH.
- Enables unattended security updates and time sync.

Bare Metal vs VPS
- CyberPanel supports both. Use a fresh OS install with no pre-installed web stacks.
- Minimum 2 GB RAM recommended (more for multiple WordPress sites). Swap is enabled if configured.

Malware Scanning
- Controlled via `enable_clamav` and `enable_maldet` in `group_vars/all.yml`. Disable either if you prefer a different stack.
- Default scan paths are set with `malware_scan_paths` (defaults to `/home`). Add additional directories that store customer content.
- ClamAV signatures update automatically (`clamav-freshclam` service). Logs land in `/var/log/clamav/daily-scan.log`.
- Maldet runs a daily background scan (`/usr/local/sbin/maldet -b`) and records detections in syslog (`journalctl -t maldet`).
- Tune scan windows via `clamav_scan_*` and `maldet_scan_*` variables to fit off-peak hours.

WordPress Hosting Best Practices
- Create a dedicated CyberPanel website (and system user) per customer. Apply resource limits via Packages for predictable performance.
- Enforce HTTPS immediately: issue Let's Encrypt in Websites ➜ Manage Website ➜ SSL, then enable Force HTTPS redirect.
- Keep LiteSpeed Cache active on every WordPress install for page caching and QUIC.cloud CDN integration.
- Enable WordPress Manager auto-updates for core/plugins, remove unused plugins/themes, and leverage staging sites before going live.
- Harden logins with 2FA plugins (e.g., WP 2FA), limit login attempts, and disable XML-RPC if customers do not rely on it.
- Schedule backups (local/remote) via CyberPanel ➜ Backup ➜ Schedule and periodically perform restore drills.
- Offer additional protection layers such as ModSecurity/OWASP CRS or a CDN WAF (Cloudflare, QUIC.cloud) for edge filtering.

Troubleshooting
- If the CyberPanel installer stalls or fails on expect prompts, rerun just the install step by toggling `cp_install_only: true` and `hardening_only: false` in `group_vars/all.yml`, or SSH into the box and run `/root/cyberpanel_install.sh` manually.
- If you lock yourself out due to SSH port changes, use your provider's console to access and fix UFW/sshd.
