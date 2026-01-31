# Aura - Powerful Dev Tools meets Beautiful Aesthetics

Aura is a custom Arch Linux-based distribution built upon the [Ambxst](https://github.com/Axenide/Ambxst) Quickshell. It seamlessly integrates a pre-configured Hyprland desktop environment with a powerful suite of development tools inherited from Omarchy.

Originally forked from Omarchy, Aura has been completely revamped to balance a high-performance workflow with the striking aesthetics of the Ambxst setup. I built this to eliminate the "start from scratch" fatigue—creating a resilient, out-of-the-box system that pairs deep utility with uncompromising eye candy.

## Features

- **Pre-configured Hyprland Environment**: Boot directly into a fully customized Hyprland desktop with Aura configs
- **Aura Auto Installer**: Friendly graphical installer for easy system setup to install Ambxst
- **Comprehensive Package Set**: Includes 150+ packages covering development tools, desktop environment, and utilities
- **Developer-Focused**: Pre-installed with Docker, Git tools, language runtimes, and dev utilities

## Desktop Environment

- **Window Manager**: Hyprland (Wayland compositor)
- **Terminal**: kitty
- **Shell**: Fish with Starship prompt
- **Application Launcher**: Ambxst
- **Status Bar**: Ambxst
- **Notifications**: Ambxst
- **File Manager**: Nautilus
- **Login Manager**: SDDM

## Included Packages

### Development Tools

- **Languages**: Typescript, Ruby, Python, Lua, Dart
- **Containers**: Docker, Docker Compose
- **Git Tools**: LazyGit, GitHub CLI
- **Editors**: Micro, VS Code (via Flatpak)

### System Utilities

- **Modern replacements**: bat, eza, ripgrep, fd, dust, zoxide
- **Monitoring**: btop, htop, inxi
- **Network**: iwd, NetworkManager, avahi

## Installation

1. Boot from the ISO
2. The Aura installer will launch automatically
3. Follow the installation wizard:
   - Select language and timezone
   - Partition your disk
   - Create user account
   - Choose hostname
4. Reboot after installation completes
5. Login - you'll be greeted with the Aura Hyprland desktop

## First Boot

On first boot, new users automatically receive:

- A welcome modal with install script
- Complete Hyprland configuration
- Aura configs in `~/.config/`
- All utility scripts in `~/.local/share/aura/bin/`
- Custom terminal (Ghostty/Foot) setup
- Fish shell with Starship prompt
- Fastfetch, btop, and other utilities pre-configured

## Keybindings

Essential Hyprland keybindings (from Aura):

- `SUPER + RETURN` - Open terminal
- `SUPER + W` - Close window
- `SUPER + 1-9` - Switch workspaces
- `SUPER + Shift + 1-9` - Move window to workspace
- `SUPER + F` - Toggle fullscreen
- `SUPER + V` - Toggle floating

```

## To Manually install Ambxst

```bash
curl -L get.axeni.de/ambxst | sh
```

incase you need it

## Customization

### Adding Packages

Edit `aura-base.packages` and add package names (one per line).
make sure there Official Pacman Packages

### Modifying Configs

To customize shell configs check:

- [https://axeni.de/ambxst/]

### Branding

Customize:

- Boot menus: `grub/grub.cfg`, `syslinux/syslinux.cfg`
- ISO metadata: `profiledef.sh`

## Differences from Current aura-iso

| Aspect | Aura-iso | Aura + Ambxst |
|--------|----------|--------|
| Build tool | Docker + archiso | archiso directly |
| Installer | Archinstall/manual | Aura Installer |
| Configs | Applied during install.sh | Pre-baked in ISO |
| Package install | Offline mirror | Pre-installed in ISO |
| First boot | Runs installer scripts | Ready to use immediately |

## Known Issues

- If Ambxst installation fails run 'sudo pacman -Syyu --noconfirm'
- then retry 'curl -L get.axeni.de/ambxst | sh'

## Contributing

To contribute:

1. Fork the Aura repository
2. Make your changes
3. Test with Aura build
4. Submit pull request

## License

Aura inherits licenses from:

- Aura  [MIT License](https://opensource.org/licenses/MIT)
- Arch Linux (GPL)
- Ambxst

## Links

- **Aura**: <https://github.com/CjLogic/Aura>
- **Ambxst**: <https://github.com/Axenide/Ambxst>
- **Arch Linux**: <https://archlinux.org>

## Support

For issues specific to:

- **Aura build process**: Create issue or discussion in this repository
- **Ambxst configs**: Create issue or discussion in Ambxst repository
- **Arch packages**: Check Arch Linux wiki

---
