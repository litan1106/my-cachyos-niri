#!/bin/bash

# Fix Waydroid networking (no internet inside Android) by letting the host
# firewall forward the container's traffic.
#
# Why this is needed: Waydroid's container service builds a NAT bridge on the
# `waydroid0` interface (subnet 192.168.240.0/24) and runs its own dnsmasq on
# the host for the Android side's DNS/DHCP. If the host firewall drops forwarded
# packets or blocks DNS/DHCP from that interface, Android boots but has no
# internet.
#
# Machine reality (verified on this box):
#   - The active firewall is **ufw**, not firewalld (firewalld isn't installed).
#   - ufw's DEFAULT_FORWARD_POLICY is "DROP", which is what kills Waydroid's
#     outbound traffic.
#   - net.ipv4.ip_forward is already 1 at runtime; we persist it so it survives
#     independent of the container service.
#
# This script still handles the firewalld path too, so it's correct if you ever
# switch backends — it detects whichever is active. If neither is active it just
# ensures IP forwarding and tells you there's nothing to open.
#
# Usage:
#   ./fix-waydroid-firewall.sh            # apply the fix
#   ./fix-waydroid-firewall.sh --revert   # undo the firewall rules it added

set -e

IFACE="waydroid0"
SYSCTL_DROPIN="/etc/sysctl.d/99-waydroid-forward.conf"

revert=0
case "${1:-}" in
  --revert)
    revert=1
    ;;
  -h|--help)
    cat <<'EOF'
Usage: fix-waydroid-firewall.sh [--revert]

Trusts the Waydroid network interface (waydroid0) in the active host firewall
and enables IP forwarding, so Android inside Waydroid gets internet.

Options:
  --revert     Remove the firewall rules this script added and delete the
               persistent IP-forwarding drop-in.
  -h, --help   Show this help message.

Detects ufw or firewalld automatically. After applying, restart the container
with:  sudo systemctl restart waydroid-container
EOF
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Try: fix-waydroid-firewall.sh --help" >&2
    exit 1
    ;;
esac

# --- Detect the active firewall backend -------------------------------------
backend="none"
if command -v ufw >/dev/null 2>&1 && \
   sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  backend="ufw"
elif command -v firewall-cmd >/dev/null 2>&1 && \
     systemctl is-active --quiet firewalld 2>/dev/null; then
  backend="firewalld"
fi

echo "Active firewall backend: $backend"

# --- IP forwarding (shared by all backends) ---------------------------------
if (( revert )); then
  if [[ -f "$SYSCTL_DROPIN" ]]; then
    echo "Removing $SYSCTL_DROPIN ..."
    sudo rm -f "$SYSCTL_DROPIN"
  fi
else
  echo "Persisting net.ipv4.ip_forward=1 in $SYSCTL_DROPIN ..."
  echo "net.ipv4.ip_forward=1" | sudo tee "$SYSCTL_DROPIN" >/dev/null
  sudo sysctl -q net.ipv4.ip_forward=1
fi

# --- Apply (or revert) the backend-specific rules ---------------------------
case "$backend" in
  ufw)
    if (( revert )); then
      echo "Removing ufw rules for $IFACE ..."
      # `delete` is a no-op (with a notice) if the rule isn't present.
      sudo ufw --force delete route allow in on "$IFACE" 2>/dev/null || true
      sudo ufw --force delete allow in on "$IFACE" to any port 53 proto udp 2>/dev/null || true
      sudo ufw --force delete allow in on "$IFACE" to any port 53 proto tcp 2>/dev/null || true
      sudo ufw --force delete allow in on "$IFACE" to any port 67 proto udp 2>/dev/null || true
      sudo ufw reload
    else
      # Allow the container's packets to be forwarded out to the internet.
      # A targeted route rule is safer than flipping DEFAULT_FORWARD_POLICY to
      # ACCEPT (which would permit *all* forwarding). ufw's built-in
      # RELATED,ESTABLISHED accept rule handles the return traffic.
      echo "Allowing forwarding in on $IFACE ..."
      sudo ufw route allow in on "$IFACE"
      # Let the Android side reach the host's dnsmasq for DNS (53) and DHCP (67),
      # scoped to the waydroid0 interface only.
      echo "Allowing DNS (53) and DHCP (67) in on $IFACE ..."
      sudo ufw allow in on "$IFACE" to any port 53 proto udp
      sudo ufw allow in on "$IFACE" to any port 53 proto tcp
      sudo ufw allow in on "$IFACE" to any port 67 proto udp
      sudo ufw reload
    fi
    ;;

  firewalld)
    if (( revert )); then
      echo "Removing $IFACE from the firewalld trusted zone ..."
      sudo firewall-cmd --zone=trusted --remove-interface="$IFACE" --permanent 2>/dev/null || true
      sudo firewall-cmd --reload
    else
      echo "Trusting $IFACE in the firewalld trusted zone ..."
      sudo firewall-cmd --zone=trusted --add-interface="$IFACE" --permanent
      sudo firewall-cmd --reload
    fi
    ;;

  none)
    echo
    echo "No active firewall (ufw/firewalld) detected — nothing to open."
    echo "If Android still has no internet, the problem is elsewhere (DNS, the"
    echo "container network, or ip_forward, which this script has set)."
    ;;
esac

# --- Restart the container so it re-establishes its network -----------------
if ! (( revert )) && [[ "$backend" != "none" ]]; then
  if systemctl is-active --quiet waydroid-container.service 2>/dev/null; then
    echo "Restarting waydroid-container.service to re-establish the network ..."
    sudo systemctl restart waydroid-container.service
  else
    echo
    echo "waydroid-container.service isn't running — start Waydroid normally"
    echo "(launch-waydroid) and the new firewall rules will apply to its network."
  fi
fi

echo
if (( revert )); then
  echo "Reverted the Waydroid firewall rules."
else
  echo "Done. Waydroid's traffic on $IFACE is now allowed through the $backend firewall."
  echo "Launch an Android session (launch-waydroid) and check connectivity in an app."
fi
