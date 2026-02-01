# ASUS Laptop Compatibility Guide for Aura

## Bootloader Configuration for ASUS Laptops

ASUS laptops (TUF, ROG, VivoBook series) use American Megatrends (AMI) firmware which has specific UEFI requirements. Aura uses **Limine bootloader** with special ASUS compatibility handling.

**Important Note:** ASUS Linux documentation recommends avoiding **GRUB** due to compatibility issues with AMI firmware. Aura uses **Limine**, which is a modern UEFI bootloader similar to systemd-boot in design philosophy. Limine with UKI and fallback support provides superior compatibility with ASUS/AMI firmware compared to GRUB.

### ASUS Firmware Characteristics

ASUS laptops using AMI firmware often have these quirks:

- NVRAM boot entries may not persist across reboots
- Firmware prefers the EFI fallback path (`\EFI\BOOT\BOOTX64.EFI`)
- Some models ignore custom NVRAM entries entirely
- Secure Boot may interfere with custom bootloaders

### Recommended Bootloader Setup

Aura's installation automatically handles ASUS compatibility by:

1. Installing Limine with fallback support enabled
2. Creating NVRAM entries for better boot reliability
3. Setting up the fallback bootloader path (`\EFI\BOOT\BOOTX64.EFI`)
4. Configuring UKI (Unified Kernel Image) for streamlined booting

### Manual ASUS Bootloader Configuration

If Limine fails to boot on your ASUS laptop, verify the following:

#### 1. Check ESP Mount and Structure

```bash
# Verify ESP is mounted at /boot
findmnt /boot

# Check ESP partition structure
ls -la /boot/EFI/
ls -la /boot/EFI/BOOT/
ls -la /boot/EFI/Linux/
```

Expected structure:

```text
/boot/
├── EFI/
│   ├── BOOT/
│   │   └── BOOTX64.EFI (Limine fallback)
│   └── Linux/
│       └── aura_linux.efi (UKI image)
├── limine.sys
└── limine.conf
```

#### 2. Verify NVRAM Boot Entries

```bash
# List all boot entries
efibootmgr -v

# You should see entries like:
# Boot0000* Aura
# Boot0001* UEFI OS (fallback)
```

#### 3. Fix Missing NVRAM Entry (ASUS-Specific)

If the Aura boot entry is missing or doesn't work:

```bash
# Get your boot disk and partition
BOOT_DISK=$(findmnt -n -o SOURCE /boot | sed 's/p\?[0-9]*$//')
BOOT_PART=$(findmnt -n -o SOURCE /boot | grep -o 'p\?[0-9]*$' | sed 's/^p//')

# Create Aura NVRAM entry pointing to UKI
sudo efibootmgr --create \
  --disk "$BOOT_DISK" \
  --part "$BOOT_PART" \
  --label "Aura" \
  --loader '\EFI\Linux\aura_linux.efi'

# Set boot order (replace XXXX with Aura boot number)
sudo efibootmgr -o XXXX,YYYY
```

#### 4. Force Fallback Bootloader (If NVRAM Fails)

Some ASUS models refuse to use NVRAM entries. Use the fallback path:

```bash
# Ensure Limine fallback is enabled
grep "ENABLE_LIMINE_FALLBACK" /etc/default/limine

# Should show: ENABLE_LIMINE_FALLBACK=yes

# Regenerate Limine configuration
sudo limine-update

# Verify fallback exists
ls -l /boot/EFI/BOOT/BOOTX64.EFI
```

The fallback bootloader (`\EFI\BOOT\BOOTX64.EFI`) is automatically loaded by ASUS firmware when no valid NVRAM entry exists.

#### 5. Disable Secure Boot (If Needed)

ASUS firmware with Secure Boot enabled will reject unsigned bootloaders:

1. Reboot and enter BIOS/UEFI (press F2 or DEL during boot)
2. Navigate to Security → Secure Boot
3. Set Secure Boot to **Disabled**
4. Save and exit (F10)

#### 6. BIOS Boot Order Settings

In ASUS BIOS:

1. Enter Boot menu
2. Set boot mode to **UEFI** (not Legacy/CSM)
3. Enable **Launch CSM**: Disabled
4. Boot Option Priorities: Move "Aura" or "UEFI OS" to top
5. Save and exit

### Troubleshooting Boot Issues

**System boots to GRUB/other bootloader instead of Limine:**

```bash
# Remove conflicting bootloaders
sudo pacman -Rns grub
sudo rm -rf /boot/EFI/grub
sudo rm -rf /boot/grub

# Reinstall Limine
sudo pacman -S --noconfirm limine limine-snapper-sync limine-mkinitcpio-hook
sudo limine-update
```

**"No bootable device" error:**

```bash
# Verify ESP partition is flagged correctly
sudo parted /dev/nvme0n1 print

# ESP partition should have "boot, esp" flags
# If not, set them:
sudo parted /dev/nvme0n1 set 1 boot on
sudo parted /dev/nvme0n1 set 1 esp on
```

**Limine menu doesn't appear:**

Check `/boot/limine.conf`:

```bash
cat /boot/limine.conf

# Should show timeout and entries
# If timeout is 0 or missing, edit it:
sudo nano /boot/limine.conf

# Add or modify:
timeout: 5

**For complete instructions check:[ASUS ARCH GUIDE](https://asus-linux.org/guides/arch-guide/)**
```
