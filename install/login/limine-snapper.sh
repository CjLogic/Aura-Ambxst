# Check if ASUS hardware - ASUS systems use systemd-boot, not Limine
IS_ASUS=false
if cat /sys/class/dmi/id/sys_vendor 2>/dev/null | grep -qi "ASUSTeK"; then
  IS_ASUS=true
  echo "ASUS hardware detected - skipping Limine setup (using systemd-boot for ASUS compatibility)"
  exit 0
fi

if command -v limine &>/dev/null; then
  sudo pacman -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook

  sudo tee /etc/mkinitcpio.conf.d/aura_hooks.conf <<EOF >/dev/null
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF
  sudo tee /etc/mkinitcpio.conf.d/thunderbolt_module.conf <<EOF >/dev/null
MODULES+=(thunderbolt)
EOF

  # Detect boot mode
  [[ -d /sys/firmware/efi ]] && EFI=true

  # Detect AMI firmware
  BIOS_VENDOR=$(cat /sys/class/dmi/id/bios_vendor 2>/dev/null || echo "")
  IS_AMI=false

  if echo "$BIOS_VENDOR" | grep -qi "American Megatrends"; then
    IS_AMI=true
    echo "Detected American Megatrends (AMI) firmware"
  fi

  # Find config location
  if [[ -f /boot/EFI/arch-limine/limine.conf ]]; then
    limine_config="/boot/EFI/arch-limine/limine.conf"
  elif [[ -f /boot/EFI/BOOT/limine.conf ]]; then
    limine_config="/boot/EFI/BOOT/limine.conf"
  elif [[ -f /boot/EFI/limine/limine.conf ]]; then
    limine_config="/boot/EFI/limine/limine.conf"
  elif [[ -f /boot/limine/limine.conf ]]; then
    limine_config="/boot/limine/limine.conf"
  elif [[ -f /boot/limine.conf ]]; then
    limine_config="/boot/limine.conf"
  else
    echo "Error: Limine config not found" >&2
    exit 1
  fi

  CMDLINE=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

  if [[ -z "$CMDLINE" ]]; then
    echo "Warning: Could not extract kernel command line from $limine_config"
    echo "Using default command line..."
    CMDLINE="root=/dev/mapper/cryptroot rootflags=subvol=@ rw"
  else
    echo "Extracted kernel command line: $CMDLINE"
  fi

  echo "Creating /etc/default/limine configuration..."
  sudo cp $AURA_PATH/default/limine/default.conf /etc/default/limine
  sudo sed -i "s|@@CMDLINE@@|$CMDLINE|g" /etc/default/limine

  echo "/etc/default/limine contents:"
  cat /etc/default/limine

  # UKI and EFI fallback are EFI only
  if [[ -z $EFI ]]; then
    sudo sed -i '/^ENABLE_UKI=/d; /^ENABLE_LIMINE_FALLBACK=/d' /etc/default/limine
  fi

  # Remove the original config file if it's not /boot/limine.conf
  if [[ "$limine_config" != "/boot/limine.conf" ]] && [[ -f "$limine_config" ]]; then
    sudo rm "$limine_config"
  fi

  # CRITICAL FIX: Don't overwrite the entire limine.conf!
  # archinstall created boot entries that we need to keep.
  # Instead, just apply Aura styling to the existing config.

  echo "Applying Aura styling to Limine configuration..."

  # Backup the archinstall-created config
  sudo cp /boot/limine.conf /boot/limine.conf.archinstall.bak

  # Update timeout (uncomment if commented, or update value)
  if grep -q "^#timeout:" /boot/limine.conf; then
    sudo sed -i 's/^#timeout:.*/timeout: 5/' /boot/limine.conf
  elif grep -q "^timeout:" /boot/limine.conf; then
    sudo sed -i 's/^timeout:.*/timeout: 5/' /boot/limine.conf
  else
    # Add timeout if it doesn't exist
    sudo sed -i '1i timeout: 5' /boot/limine.conf
  fi

  # Update/add branding
  if grep -q "^interface_branding:" /boot/limine.conf; then
    sudo sed -i 's/^interface_branding:.*/interface_branding: Aura Bootloader/' /boot/limine.conf
  else
    sudo sed -i '2i interface_branding: Aura Bootloader' /boot/limine.conf
  fi

  if grep -q "^interface_branding_color:" /boot/limine.conf; then
    sudo sed -i 's/^interface_branding_color:.*/interface_branding_color: 6/' /boot/limine.conf
  else
    sudo sed -i '3i interface_branding_color: 6' /boot/limine.conf
  fi

  echo "✓ Aura styling applied while preserving archinstall boot entries"


  # Match Snapper configs if not installing from the ISO
  if [[ -z ${AURA_CHROOT_INSTALL:-} ]]; then
    if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
      sudo snapper -c root create-config /
    fi

    if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
      sudo snapper -c home create-config /home
    fi
  fi

  # Verify fallback bootloader was created (critical for ASUS/AMI firmware)
  echo "Verifying fallback bootloader setup..."

  if [[ -n $EFI ]]; then
    # Check if fallback exists
    if [[ ! -f /boot/EFI/BOOT/BOOTX64.EFI ]]; then
      echo "Warning: Fallback bootloader not found at /boot/EFI/BOOT/BOOTX64.EFI"
      echo "Attempting to create fallback manually..."

      # Ensure directory exists
      sudo mkdir -p /boot/EFI/BOOT

      # Copy Limine bootloader to fallback location
      if [[ -f /boot/EFI/Linux/aura_linux.efi ]]; then
        sudo cp /boot/EFI/Linux/aura_linux.efi /boot/EFI/BOOT/BOOTX64.EFI
        echo "✓ Fallback bootloader created from UKI"
      elif [[ -f /usr/share/limine/BOOTX64.EFI ]]; then
        sudo cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
        echo "✓ Fallback bootloader created from Limine package"
      else
        echo "Error: Could not find Limine bootloader to copy to fallback location"
      fi
    else
      echo "✓ Fallback bootloader exists at /boot/EFI/BOOT/BOOTX64.EFI"
    fi

    # Verify ESP partition flags are correct
    BOOT_DEVICE=$(findmnt -n -o SOURCE /boot | sed 's/p\?[0-9]*$//')
    BOOT_PART_NUM=$(findmnt -n -o SOURCE /boot | grep -o '[0-9]*$')

    if [[ -n "$BOOT_DEVICE" ]] && [[ -n "$BOOT_PART_NUM" ]]; then
      echo "Checking ESP partition flags on ${BOOT_DEVICE}${BOOT_PART_NUM}..."
      PART_FLAGS=$(sudo parted "$BOOT_DEVICE" print 2>/dev/null | grep "^ *$BOOT_PART_NUM " | grep -o "boot.*" || echo "")

      if echo "$PART_FLAGS" | grep -q "boot"; then
        echo "✓ ESP partition has boot flag"
      else
        echo "Warning: ESP partition missing boot flag - attempting to set..."
        sudo parted "$BOOT_DEVICE" set "$BOOT_PART_NUM" boot on 2>/dev/null || true
        sudo parted "$BOOT_DEVICE" set "$BOOT_PART_NUM" esp on 2>/dev/null || true
      fi
    fi
  fi

  # Enable quota to allow space-aware algorithms to work
  sudo btrfs quota enable / 2>/dev/null || true

  # Tweak default Snapper configs
  sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^SPACE_LIMIT="0.5"/SPACE_LIMIT="0.3"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^FREE_LIMIT="0.2"/FREE_LIMIT="0.3"/' /etc/snapper/configs/{root,home}

  chrootable_systemctl_enable limine-snapper-sync.service
fi

echo "Re-enabling mkinitcpio hooks..."

# Restore the specific mkinitcpio pacman hooks
if [ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled ]; then
  sudo mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled /usr/share/libalpm/hooks/90-mkinitcpio-install.hook
fi

if [ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled ]; then
  sudo mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook
fi

echo "mkinitcpio hooks re-enabled"

# Run limine-update to generate boot entries
echo "Running limine-update to generate bootloader configuration..."
sudo limine-update

# Show what limine-update created
# echo ""
# echo "Checking generated limine.conf..."
# if [[ -f /boot/limine.conf ]]; then
#   echo "/boot/limine.conf contents:"
#   cat /boot/limine.conf
#   echo ""

  # CRITICAL for ASUS fallback: Copy config to where fallback bootloader can find it
  # Always copy, even if fallback already exists (might be auto-generated without config)
  if [[ -n $EFI ]] && [[ -f /boot/EFI/BOOT/BOOTX64.EFI ]]; then
    echo "Copying limine.conf to fallback bootloader location..."
    sudo mkdir -p /boot/EFI/BOOT
    sudo cp /boot/limine.conf /boot/EFI/BOOT/limine.conf
    echo "✓ Config copied to /boot/EFI/BOOT/limine.conf"
  fi
else
  echo "ERROR: /boot/limine.conf was not created!"
fi

# CRITICAL FIX for ASUS: Create proper fallback that points to actual Limine bootloader
if [[ -n $EFI ]]; then
  echo "Creating ASUS-compatible fallback bootloader..."

  # Ensure directory exists
  sudo mkdir -p /boot/EFI/BOOT

  # The fallback needs to be a COPY of the actual Limine bootloader
  # Find where limine-update put the main bootloader
  if [[ -f /boot/EFI/limine/limine_x64.efi ]]; then
    sudo cp /boot/EFI/limine/limine_x64.efi /boot/EFI/BOOT/BOOTX64.EFI
    echo "✓ Fallback created from /boot/EFI/limine/limine_x64.efi"
  elif [[ -f /boot/EFI/limine/BOOTX64.EFI ]]; then
    sudo cp /boot/EFI/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
    echo "✓ Fallback created from /boot/EFI/limine/BOOTX64.EFI"
  else
    echo "Warning: Could not find Limine bootloader in /boot/EFI/limine/"
    echo "Trying to copy from package..."
    if [[ -f /usr/share/limine/BOOTX64.EFI ]]; then
      sudo cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
      echo "✓ Fallback created from /usr/share/limine/"
    fi
  fi

  # CRITICAL: Copy limine.conf to where the fallback bootloader can find it
  # Limine searches for config in these locations (in order):
  # 1. Same directory as the EFI file
  # 2. /boot/limine.conf
  # Since the fallback is at /boot/EFI/BOOT/BOOTX64.EFI, copy config there
  # Always copy to ensure fallback has the latest config (not just auto-generated one)
  if [[ -f /boot/limine.conf ]]; then
    sudo mkdir -p /boot/EFI/BOOT
    sudo cp /boot/limine.conf /boot/EFI/BOOT/limine.conf
    echo "✓ Copied limine.conf to /boot/EFI/BOOT/ for fallback bootloader"
  fi

  # Verify fallback was created
  if [[ -f /boot/EFI/BOOT/BOOTX64.EFI ]]; then
    FALLBACK_SIZE=$(stat -c%s /boot/EFI/BOOT/BOOTX64.EFI)
    echo "✓ Fallback bootloader verified: $FALLBACK_SIZE bytes"

    if [[ -f /boot/EFI/BOOT/limine.conf ]]; then
      echo "✓ Fallback configuration verified"
    else
      echo "⚠ Warning: limine.conf not found in /boot/EFI/BOOT/"
    fi
  else
    echo "ERROR: Fallback bootloader was not created!"
  fi
fi

if [[ -n $EFI ]] && efibootmgr &>/dev/null; then
  echo "Configuring EFI boot entries..."

  # Remove old/duplicate Limine entries
  while IFS= read -r bootnum; do
    echo "Removing old boot entry: Boot$bootnum"
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1
  done < <(efibootmgr | grep -E "^Boot[0-9]{4}\*? Arch Linux Limine" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')

  # Remove old Aura entries to avoid duplicates
  while IFS= read -r bootnum; do
    echo "Removing old Aura entry: Boot$bootnum"
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1
  done < <(efibootmgr | grep -E "^Boot[0-9]{4}\*? Aura" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')

  # Get boot disk and partition info
  BOOT_SOURCE=$(findmnt -n -o SOURCE /boot 2>/dev/null)

  if [[ -n "$BOOT_SOURCE" ]]; then
    BOOT_DISK=$(echo "$BOOT_SOURCE" | sed 's/p\?[0-9]*$//')
    BOOT_PART=$(echo "$BOOT_SOURCE" | grep -o 'p\?[0-9]*$' | sed 's/^p//')

    echo "Boot disk: $BOOT_DISK"
    echo "Boot partition: $BOOT_PART"

    # Try to find UKI file first, then fall back to regular Limine bootloader
    uki_file=$(find /boot/EFI/Linux/ -name "aura*.efi" -printf "%f\n" 2>/dev/null | head -1)
    limine_file=""

    # Check for Limine bootloader in standard location
    if [[ -f /boot/EFI/limine/limine_x64.efi ]]; then
      limine_file="limine_x64.efi"
    elif [[ -f /boot/EFI/limine/BOOTX64.EFI ]]; then
      limine_file="BOOTX64.EFI"
    fi

    # Determine which bootloader to use for NVRAM entry
    BOOT_LOADER_PATH=""
    if [[ -n "$uki_file" ]]; then
      BOOT_LOADER_PATH="\\EFI\\Linux\\$uki_file"
      echo "Found UKI: $uki_file"
    elif [[ -n "$limine_file" ]]; then
      BOOT_LOADER_PATH="\\EFI\\limine\\$limine_file"
      echo "Found Limine bootloader: $limine_file (UKI not available)"
    fi

    if [[ -n "$BOOT_LOADER_PATH" ]]; then
      # Skip Apple hardware (uses different boot mechanism)
      if ! echo "$BIOS_VENDOR" | grep -qi "Apple"; then
        # Create NVRAM entry for Aura
        # This works on most hardware including ASUS, but ASUS firmware may ignore it
        echo "Creating NVRAM boot entry for Aura pointing to: $BOOT_LOADER_PATH"

        if sudo efibootmgr --create \
          --disk "$BOOT_DISK" \
          --part "$BOOT_PART" \
          --label "Aura" \
          --loader "$BOOT_LOADER_PATH" 2>&1; then
          echo "NVRAM entry created successfully"

          # Set Aura as first boot option
          AURA_BOOTNUM=$(efibootmgr | grep "Aura" | sed 's/^Boot\([0-9]\{4\}\).*/\1/' | head -1)
          if [[ -n "$AURA_BOOTNUM" ]]; then
            echo "Setting Aura (Boot$AURA_BOOTNUM) as first boot option"
            # Get current boot order and prepend Aura
            CURRENT_ORDER=$(efibootmgr | grep "BootOrder:" | sed 's/BootOrder: //' | sed "s/$AURA_BOOTNUM,\?//g" | sed 's/,$//')
            sudo efibootmgr -o "$AURA_BOOTNUM${CURRENT_ORDER:+,$CURRENT_ORDER}" >/dev/null 2>&1 || true
          fi
        else
          echo "Warning: Failed to create NVRAM entry"
          if [[ "$IS_ASUS" == "true" ]] || [[ "$IS_AMI" == "true" ]]; then
            echo "Note: ASUS/AMI firmware detected - will rely on fallback bootloader"
          fi
        fi

        # For ASUS/AMI: Ensure fallback bootloader exists as primary boot method
        if [[ "$IS_ASUS" == "true" ]] || [[ "$IS_AMI" == "true" ]]; then
          echo "ASUS/AMI firmware detected - ensuring fallback bootloader is in place"

          # Verify fallback exists (should be created by ENABLE_LIMINE_FALLBACK=yes)
          if [[ -f /boot/EFI/BOOT/BOOTX64.EFI ]]; then
            echo "✓ Fallback bootloader exists at /boot/EFI/BOOT/BOOTX64.EFI"
          else
            echo "Warning: Fallback bootloader not found!"
            echo "This may cause boot issues on ASUS hardware"
          fi
        fi
      else
        echo "Apple hardware detected - skipping NVRAM entry creation"
      fi
    else
      echo "Warning: UKI file not found in /boot/EFI/Linux/"
      echo "Boot entry creation skipped"
    fi
  else
    echo "Warning: Could not determine boot partition"
    echo "Boot entry creation skipped"
  fi

  echo "Current EFI boot configuration:"
  efibootmgr || true
fi
