#!/usr/bin/env bash
#|---/ /+-------------------------------------+---/ /|#
#|--/ /-| Script to apply pre install configs |--/ /-|#
#|-/ /--| Prasanth Rangan                     |-/ /--|#
#|/ /---+-------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

flg_DryRun=${flg_DryRun:-0}

# grub
if pkg_installed grub && [ -f /boot/grub/grub.cfg ]; then
    print_log -sec "bootloader" -b "detected :: " "grub..."

    if [ ! -f /etc/default/grub.hyde.bkp ] && [ ! -f /boot/grub/grub.hyde.bkp ]; then
        [ "${flg_DryRun}" -eq 1 ] || sudo cp /etc/default/grub /etc/default/grub.hyde.bkp
        [ "${flg_DryRun}" -eq 1 ] || sudo cp /boot/grub/grub.cfg /boot/grub/grub.hyde.bkp

        # Only if the nvidia installation doesn't skip
        if nvidia_detect; then
            if [ ${flg_Nvidia} -eq 1 ]; then
                print_log -g "[bootloader] " -b "configure :: " "nvidia detected, adding nvidia_drm.modeset=1 to boot option..."
                gcld=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "/etc/default/grub" | cut -d'"' -f2 | sed 's/\b nvidia_drm.modeset=.\b//g')
                [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT=\"${gcld} nvidia_drm.modeset=1\"" /etc/default/grub
            else
                print_log -g "[bootloader] " -b "skip :: " "nvidia detected, skipping nvidia_drm.modeset=1 to boot option..."
            fi
        fi

        # Set default GRUB theme to Retroboot (first option)
        grubtheme="Retroboot"
        print_log -g "[bootloader] " -b "set :: " "grub theme // ${grubtheme} (default)"
        echo ""
        # shellcheck disable=SC2154
        [ "${flg_DryRun}" -eq 1 ] || sudo tar -xzf "${cloneDir}/Source/arcs/Grub_${grubtheme}.tar.gz" -C /usr/share/grub/themes/
        [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved
        /^GRUB_GFXMODE=/c\GRUB_GFXMODE=1280x1024x32,auto
        /^GRUB_THEME=/c\GRUB_THEME=\"/usr/share/grub/themes/${grubtheme}/theme.txt\"
        /^#GRUB_THEME=/c\GRUB_THEME=\"/usr/share/grub/themes/${grubtheme}/theme.txt\"
        /^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true" /etc/default/grub
        [ "${flg_DryRun}" -eq 1 ] || sudo grub-mkconfig -o /boot/grub/grub.cfg

    else
        print_log -y "[bootloader] " -b "exist :: " "grub is already configured..."
    fi
fi

# systemd-boot
if pkg_installed systemd && nvidia_detect && [ "$(bootctl status 2>/dev/null | awk '{if ($1 == "Product:") print $2}')" == "systemd-boot" ]; then
    print_log -sec "bootloader" -stat "detected" "systemd-boot"

    if [ "$(find /boot/loader/entries/ -type f -name '*.conf.hyde.bkp' 2>/dev/null | wc -l)" -ne "$(find /boot/loader/entries/ -type f -name '*.conf' 2>/dev/null | wc -l)" ]; then
        print_log -g "[bootloader] " -b " :: " "nvidia detected, adding nvidia_drm.modeset=1 to boot option..."
        if [[ "${flg_DryRun}" -ne 1 ]]; then
            find /boot/loader/entries/ -type f -name "*.conf" | while read -r imgconf; do
                sudo cp "${imgconf}" "${imgconf}.hyde.bkp"
                sdopt=$(grep -w "^options" "${imgconf}" | sed 's/\b quiet\b//g' | sed 's/\b splash\b//g' | sed 's/\b nvidia_drm.modeset=.\b//g')
                sudo sed -i "/^options/c${sdopt} quiet splash nvidia_drm.modeset=1" "${imgconf}"
            done
        fi
    else
        print_log -y "[bootloader] " -stat "skipped" "systemd-boot is already configured..."
    fi
fi

# pacman

if [ -f /etc/pacman.conf ] && [ ! -f /etc/pacman.conf.hyde.bkp ]; then
    print_log -g "[PACMAN] " -b "modify :: " "adding extra spice to pacman..."

    # shellcheck disable=SC2154
    [ "${flg_DryRun}" -eq 1 ] || sudo cp /etc/pacman.conf /etc/pacman.conf.hyde.bkp
    [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^#Color/c\Color\nILoveCandy
    /^#VerbosePkgLists/c\VerbosePkgLists
    /^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf
    [ "${flg_DryRun}" -eq 1 ] || sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

    print_log -g "[PACMAN] " -b "update :: " "packages..."
    [ "${flg_DryRun}" -eq 1 ] || sudo pacman -Syyu
    [ "${flg_DryRun}" -eq 1 ] || sudo pacman -Fy
else
    print_log -sec "PACMAN" -stat "skipped" "pacman is already configured..."
fi

if grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
    print_log -sec "CHAOTIC-AUR" -stat "skipped" "Chaotic AUR entry found in pacman.conf..."
else
    # Set default to install Chaotic AUR
    print_log -sec "Chaotic-aur" -stat "Installation" "Installing Chaotic AUR (default)..."
    if [[ "${flg_DryRun}" -ne 1 ]]; then
        sudo pacman-key --init
        sudo "${scrDir}/chaotic_aur.sh" --install
    fi
fi
