CyberPanel Secure Install (Ansible)

Overview
- Installs CyberPanel (OpenLiteSpeed) on Ubuntu 22.04.
- Applies baseline server hardening (SSH, firewall, fail2ban, unattended upgrades, swap, time sync).
- Opens only required ports (80/443/8090 by default). Optional DNS and mail ports are toggleable.
- Adds optional scheduled malware scanning (ClamAV + Linux Malware Detect).
- Alternative playbooks included for HestiaCP and CloudPanel:
  - HestiaCP: `ansible/hestia.yml` (panel on 8083)
  - CloudPanel: `ansible/cloudpanel.yml` (panel on 8443)

Requirements
- Target: Fresh Ubuntu 22.04 VPS or bare‑metal server with FQDN ready (e.g., panel.example.com)
- Control node: Ansible 2.13+ with SSH access to the target
- If using the automated installer step: Python `pexpect` on the control node (`pip install pexpect`)
- UFW tasks use the `community.general` collection (`ansible-galaxy collection install community.general`)

Quick Start (Fresh Server)
1) Edit `ansible/inventory.ini` to include your server and SSH details.
2) Edit `ansible/group_vars/all.yml` to set hostname, SSH port, and admin password.
   - For password-based SSH, do not store the password in Git; run Ansible with prompts (`--ask-pass --ask-become-pass`).
3) Create or copy an SSH key and test access (recommended)
   - Generate: `ssh-keygen -t ed25519 -a 100 -C "customer@<panel-fqdn>" -f ~/.ssh/id_ed25519_panel`
   - Copy: `ssh-copy-id -i ~/.ssh/id_ed25519_panel.pub customer@<server-ip>`
   - Test: `ssh -i ~/.ssh/id_ed25519_panel customer@<server-ip>`
   - Optional inventory entry: add `ansible_ssh_private_key_file=~/.ssh/id_ed25519_panel`
4) Ensure DNS A record points your FQDN to the server (e.g., `cyberpanel.naturecure.blog -> <server-ip>`), then run one of the playbooks (CloudPanel is the default recommendation):

   CloudPanel (default): ansible-playbook -i ansible/inventory.ini ansible/cloudpanel.yml
   CyberPanel:           ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
   HestiaCP:             ansible-playbook -i ansible/inventory.ini ansible/hestia.yml

Notes
- By default, the playbook hardens the server and installs CyberPanel using OpenLiteSpeed.
- Set `enable_dns`/`enable_mail` to true in `group_vars/all.yml` if you plan to run DNS or mail on the panel host; firewall rules will be opened accordingly.
- Installation uses the upstream CyberPanel installer. The playbook attempts to answer prompts via Ansible's `expect` module. If the installer changes prompts, you may need to adjust `responses` patterns in `playbook.yml`.
- After install, visit https://your-fqdn-or-ip:8090/ and log in as `admin` using the password you set.
- Password-based SSH is supported but discouraged; if you temporarily rely on it, run with `--ask-pass --ask-become-pass` (or export `ansible_password`/`ansible_become_password` securely) and avoid committing credentials to Git.

Security Defaults
- Creates a new sudo user and disables root SSH login and password auth (key-based only).
- Changes SSH port (set via `ssh_port`). Make sure your security groups/firewalls allow it.
- Enables UFW with default deny inbound, allow outbound.
- Enables Fail2Ban for SSH (all playbooks configure `jail.local`).
- Enables unattended security updates and time sync.

SSH Key Setup (first run ease and security)
- Generate a key on your control machine: `ssh-keygen -t ed25519 -a 100 -C "customer@cpanel" -f ~/.ssh/id_ed25519_cpanel`
- Copy it to the server (will prompt for your password): `ssh-copy-id -i ~/.ssh/id_ed25519_cpanel.pub -p 22 customer@<SERVER_IP>`
- Test login: `ssh -i ~/.ssh/id_ed25519_cpanel -p 22 customer@<SERVER_IP>`
- Optional: set `ansible_ssh_private_key_file=~/.ssh/id_ed25519_cpanel` in `ansible/inventory.ini` to use the key automatically.

Bare Metal vs VPS
- CyberPanel supports both. Use a fresh OS install with no pre-installed web stacks.
- Minimum 2 GB RAM recommended (more for multiple WordPress sites). Swap is enabled if configured.

High-memory servers
- With large RAM (e.g., 72 GiB), swap is not needed; this playbook sets `enable_swap: false` by default. If you want swap for crash-dumps or hibernation, flip it back to `true` and re-run.
- Malware scans are scheduled with low CPU priority via `nice` and can be moved to off-peak hours using `clamav_scan_*`/`maldet_scan_*` variables.

Malware Scanning & Performance Automation
- Controlled via `enable_clamav` and `enable_maldet` in `group_vars/all.yml`. Disable either if you prefer a different stack.
- Default scan paths are set with `malware_scan_paths` (defaults to `/home`). Add additional directories that store customer content.
- ClamAV signatures update automatically (`clamav-freshclam` service). Logs land in `/var/log/clamav/daily-scan.log`.
- Maldet runs a daily background scan (`/usr/local/sbin/maldet -b`) and records detections in syslog (`journalctl -t maldet`).
 - Tune scan windows via `clamav_scan_*` and `maldet_scan_*` variables to fit off-peak hours.
- CloudPanel automation additionally:
  - Tunes MariaDB automatically (`mariadb_tuning`, `mariadb_buffer_pool_pct`) and writes `/etc/mysql/mariadb.conf.d/90-cloudpanel-tuning.cnf`.
  - Installs and hardens Redis (`enable_redis`, `redis_bind_address`, `redis_maxmemory_percent`) for WordPress object/page caching.
  - All services restart as needed with handlers so your settings persist across runs.

CloudPanel Variable Quick Reference (`ansible/group_vars/all.yml`)
- `enable_redis`: Toggle Redis deployment (default true).
- `redis_bind_address`: Usually `127.0.0.1`; change only if exposing Redis.
- `redis_maxmemory_percent`: Percentage of total RAM reserved for Redis (default 25%).
- `mariadb_tuning`: Enable/disable MariaDB tuning drop-in.
- `mariadb_buffer_pool_pct`: Percent of RAM dedicated to InnoDB buffer pool (default 60%).
- Values calculate dynamically per server; rerun the playbook after hardware changes to regenerate configs.

Choose a Panel: Pros/Cons (quick)
- CyberPanel (OpenLiteSpeed)
  - Pros: Very fast LSCache/QUIC; WP one-click; free OLS.
  - Cons: Some advanced manager features are paid.
- HestiaCP (Nginx+PHP-FPM)
  - Pros: Free, simple, built-in quick install for WordPress; familiar panel.
  - Cons: Fewer performance features vs OLS unless tuned; app installer is basic.
- CloudPanel (Nginx + PHP-FPM, MariaDB)
  - Pros: Modern UI, one-click WordPress, multiple PHP versions per site.
  - Cons: Opinionated stack; fewer bundled mail/DNS features (good if you separate mail/DNS).

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
