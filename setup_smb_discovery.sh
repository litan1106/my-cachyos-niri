#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g. using sudo)"
  exit 1
fi

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

echo "==> Enabling and starting services..."
systemctl enable --now smb.service
systemctl enable --now avahi-daemon.service
systemctl enable --now wsdd.service
systemctl enable --now ufw.service

echo "==> Setup Complete! mDNS, WSDD, and UFW are now fully configured for Samba."
