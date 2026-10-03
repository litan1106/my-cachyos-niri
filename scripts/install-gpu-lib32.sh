#!/bin/bash

# Detect the GPU vendor(s) via lspci and install the matching 32-bit (lib32)
# graphics drivers needed for Wine/Proton gaming. Handles AMD, Intel, and
# NVIDIA, including multi-GPU machines (installs drivers for every vendor found).
#
# Requires the [multilib] repo enabled in /etc/pacman.conf and sudo for pacman.
#
# Sourced by the gaming install scripts as `install_gpu_lib32`, and runnable
# standalone: ./install-gpu-lib32.sh

install_gpu_lib32() {
  echo "Detecting GPU vendor(s) for lib32 graphics drivers..."

  if ! command -v lspci >/dev/null 2>&1; then
    echo "Installing pciutils (needed to detect the GPU)..."
    sudo pacman -S --needed --noconfirm pciutils
  fi

  # lib32-mesa provides the shared 32-bit OpenGL/Vulkan loader bits used
  # regardless of vendor, so it's always installed.
  local packages=(lib32-mesa)
  local gpus
  gpus="$(lspci -nn | grep -iE 'vga|3d|display' || true)"

  # Match AMD without tripping on the "ati" inside "VGA compATIble controller":
  # modern cards show "[AMD/ATI]", older ones "ATI Technologies".
  if grep -iqE 'amd|advanced micro devices|ati technologies' <<<"$gpus"; then
    echo "  - AMD GPU detected"
    packages+=(lib32-vulkan-radeon)
  fi
  if grep -iq 'intel' <<<"$gpus"; then
    echo "  - Intel GPU detected"
    packages+=(lib32-vulkan-intel)
  fi
  if grep -iq 'nvidia' <<<"$gpus"; then
    echo "  - NVIDIA GPU detected"
    # Proprietary driver's 32-bit userspace (the common gaming case). On a
    # nouveau-only setup, swap this for lib32-vulkan-nouveau.
    packages+=(lib32-nvidia-utils)
  fi

  if (( ${#packages[@]} <= 1 )); then
    echo "  ! Could not identify an AMD/Intel/NVIDIA GPU from lspci." >&2
    echo "    Installing lib32-mesa only; install your vendor's lib32 Vulkan" >&2
    echo "    driver manually if games fail to find a GPU." >&2
  fi

  # Deduplicate (multi-GPU of the same vendor shouldn't double-list a package).
  mapfile -t packages < <(printf '%s\n' "${packages[@]}" | sort -u)

  echo "Installing lib32 graphics drivers: ${packages[*]}"
  sudo pacman -S --needed --noconfirm "${packages[@]}"
}

# Run directly when executed rather than sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e
  install_gpu_lib32
fi
