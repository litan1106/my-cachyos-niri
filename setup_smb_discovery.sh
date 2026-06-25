#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g. using sudo)"
  exit 1
fi

echo "==> 1. Installing Required Packages..."
# wsdd is required for modern Windows 10/11 discovery
# nss-mdns is required for .local hostname resolution
pacman -S --needed --noconfirm samba avahi nss-mdns wsdd

echo "==> 2. Configuring Hostname Resolution (nsswitch.conf)..."
if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
  # Insert mdns_minimal [NOTFOUND=return] before 'resolve' or 'dns'
  sed -i 's/^\(hosts:.*\) resolve/\1 mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
  if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
      sed -i 's/^\(hosts:.*\) dns/\1 mdns_minimal [NOTFOUND=return] dns/' /etc/nsswitch.conf
  fi
  echo "Updated /etc/nsswitch.conf with mdns_minimal."
else
  echo "/etc/nsswitch.conf is already configured for mDNS."
fi

echo "==> 3. Configuring Samba (/etc/samba/smb.conf)..."
mkdir -p /etc/samba
if [ -f /etc/samba/smb.conf ]; then
  mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
  echo "Backed up existing /etc/samba/smb.conf to /etc/samba/smb.conf.bak"
fi

# Drop in an Ubuntu-style smb.conf
cat << 'EOF' > /etc/samba/smb.conf
[global]
   netbios name = %h
   workgroup = WORKGROUP
   server string = %h Desktop
   
   # Ubuntu-like defaults for name resolution and proxy
   dns proxy = no

   # Authentication & PAM
   server role = standalone server
   security = user
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes

   # Map unknown users to guest
   map to guest = bad user
   usershare allow guests = yes

   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

   # --- 8K Streaming & Extreme Throughput ---
   socket options = TCP_NODELAY
   min receivefile size = 16384
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384
   
   # Maximize packet sizes for SMB2/3 (8MB)
   smb2 max read = 8388608
   smb2 max write = 8388608
   smb2 max trans = 8388608
   
   # Multi-channel and protocol enforcement
   server multi channel support = yes
   server min protocol = SMB3
   client min protocol = SMB3
   strict locking = no
   getwd cache = yes

   # Connection Lifespan Tweaks
   deadtime = 15
   keepalive = 20

   # --- iPad & Apple Caching Fixes (VFS Fruit) ---
   vfs objects = catia fruit streams_xattr
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix = yes
   fruit:aapl = yes
   fruit:nfs_aces = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes
   mangled names = no
   ea support = no
   store dos attributes = no
   map archive = no
   map hidden = no
   map system = no

   # --- Fast Directory Listing (Avoid Long Scans) ---
   host msdfs = no
   # Prevent Windows/macOS from forcing long network scans to build remote search indexes/thumbnails
   veto files = /._*/.DS_Store/.Trashes/.TemporaryItems/.Spotlight-V100/Thumbs.db/
   delete veto files = yes

[homes]
   comment = Home Directories
   browseable = no
   read only = yes
   create mask = 0700
   directory mask = 0700
   valid users = %S

[printers]
   comment = All Printers
   browseable = no
   path = /var/spool/samba
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700

[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
EOF
echo "Created Ubuntu-style /etc/samba/smb.conf"

echo "==> Configuring Avahi (mDNS) for Samba..."
mkdir -p /etc/avahi/services
cat << 'EOF' > /etc/avahi/services/samba.service
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h SMB</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
</service-group>
EOF

echo "==> Configuring UFW Firewall Rules..."
# Allow Samba
ufw allow 139/tcp
ufw allow 445/tcp

# Allow mDNS (Apple iPad/Mac discovery)
ufw allow mdns

# Allow WSDD (Windows discovery)
ufw allow 3702/udp
ufw allow 5357/tcp

echo "==> Reloading UFW..."
ufw reload

echo "==> 4. Enabling and Starting Services..."
systemctl enable --now smb.service
systemctl enable --now nmb.service
systemctl enable --now avahi-daemon.service
systemctl enable --now wsdd.service
systemctl enable --now ufw.service

echo "==> Setup Complete!"
echo "Please run 'testparm' to verify the validity of /etc/samba/smb.conf."
echo "mDNS, WSDD, NetBIOS, and UFW are now fully configured to mimic Ubuntu's out-of-the-box network discovery."
