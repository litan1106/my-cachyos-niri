#!/usr/bin/env bash
# fix-monitor-wake.sh
# Fixes: black screen on monitor wake for RX 9060 XT (RDNA 4) + HDMI on niri/Wayland
# Root cause: amdgpu REG_WAIT timeout on optc401_disable_crtc during DPMS off/on

set -e

echo "=== Fix 1: amdgpu kernel module parameters ==="
# psr=0   — disable Panel Self Refresh (causes CRTC disable to hang on HDMI)
# runpm=0 — disable GPU runtime power management (prevents deep idle during DPMS off,
#            which is what triggers the optc401_disable_crtc REG_WAIT timeout)
sudo tee /etc/modprobe.d/amdgpu.conf << 'MODPROBE'
# AMD GPU display wake fix for RX 9060 XT (RDNA 4 / navi48) + HDMI
# Fixes: amdgpu REG_WAIT timeout on optc401_disable_crtc (black screen on wake)
options amdgpu psr=0 runpm=0
MODPROBE
echo "✓ /etc/modprobe.d/amdgpu.conf written"

echo ""
echo "=== Fix 2: Rebuild initramfs ==="
sudo mkinitcpio -P
echo "✓ Initramfs rebuilt"

echo ""
echo "=== Fix 3: Verify parameters will apply on next boot ==="
modprobe --showconfig 2>/dev/null | grep amdgpu || \
    grep amdgpu /etc/modprobe.d/amdgpu.conf
echo ""
echo "✓ All done! Reboot to apply the fix."
echo ""
echo "After reboot, verify with:"
echo "  cat /sys/module/amdgpu/parameters/psr"
echo "  cat /sys/module/amdgpu/parameters/runpm"
echo "  (Both should return 0)"
