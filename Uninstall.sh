#!/bin/bash
#
# This script uninstalls the Hyprland <-> Gamescope session switcher.
# It removes all configuration files and scripts created by the installer,
# restoring SDDM and Hyprland to their default states.
# CORRECTED: This version no longer removes the main hyprland.desktop file.
#

# --- Pre-flight Checks and Setup ---
# Define colors for output
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

# Ensure the script is not run as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${C_RED}Error: This script must not be run as root. It will use 'sudo' when necessary.${C_NC}"
  exit 1
fi

# Get current user information
USER_NAME=$(whoami)
USER_HOME=$(eval echo "~$USER_NAME")

# --- Banner ---
echo -e "${C_BLUE}===================================================================${C_NC}"
echo -e "${C_BLUE} Uninstalling Hyprland <-> Gamescope Session Switcher...${C_NC}"
echo -e "${C_BLUE}===================================================================${C_NC}"
echo

# --- Script Variables ---
HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf"
SWITCH_SCRIPT_PATH="$USER_HOME/.local/bin/switch-session.sh"
XSESSION_PATH="$USER_HOME/.xsession"
SERVICE_OVERRIDE_DIR="/etc/systemd/user/gamescope-session-plus@.service.d"

#=======================================================
# STEP 1: REMOVE SDDM AUTOLOGIN CONFIGURATION
#=======================================================
echo -e "${C_BLUE}==> Step 1: Removing SDDM Configuration...${C_NC}"
if [ -f "/etc/sddm.conf" ]; then
    sudo rm -f /etc/sddm.conf
    echo "-> Removed /etc/sddm.conf"
else
    echo "-> SDDM configuration not found, skipping."
fi

#=======================================================
# STEP 2: REMOVE CUSTOM WAYLAND SESSION FILES
#=======================================================
echo -e "\n${C_BLUE}==> Step 2: Removing Custom Wayland Session Files...${C_NC}"
# CORRECTED: Only removes the files the installer created.
sudo rm -f /usr/share/wayland-sessions/switcher.desktop
sudo rm -f /usr/share/wayland-sessions/gamescope-steam.desktop
echo "-> Removed custom switcher and gamescope-steam .desktop files."

#=======================================================
# STEP 3: REMOVE USER SCRIPTS AND FILES
#=======================================================
echo -e "\n${C_BLUE}==> Step 3: Removing User Scripts...${C_NC}"
rm -f "$XSESSION_PATH"
rm -f "$SWITCH_SCRIPT_PATH"
rm -f "$HOME/.next-session" # Remove any leftover state file
echo "-> Removed ~/.xsession and the wofi switcher script."

#=======================================================
# STEP 4: REMOVE HYPRLAND HOTKEY
#=======================================================
echo -e "\n${C_BLUE}==> Step 4: Removing Hotkey from Hyprland Configuration...${C_NC}"
if [ -f "$HYPR_CONF" ]; then
    # This command finds the comment line we added and deletes it AND the line that follows it.
    sed -i '/# Switch between Gamescope and Hyprland/{N;d;}' "$HYPR_CONF"
    # This cleans up any other stray bindings for SUPER, F12 just in case.
    sed -i '/^bind = SUPER, F12/d' "$HYPR_CONF"
    echo "-> Removed SUPER+F12 binding from $HYPR_CONF"
else
    echo "-> Hyprland config not found, skipping."
fi

#=======================================================
# STEP 5: REMOVE SYSTEMD OVERRIDE
#=======================================================
echo -e "\n${C_BLUE}==> Step 5: Removing Systemd Override for Gamescope...${C_NC}"
if [ -d "$SERVICE_OVERRIDE_DIR" ]; then
    sudo rm -rf "$SERVICE_OVERRIDE_DIR"
    systemctl --user daemon-reload
    echo "-> Removed systemd override and reloaded daemon."
else
    echo "-> Systemd override directory not found, skipping."
fi

#=======================================================
# FINALIZATION
#=======================================================
echo ""
echo -e "${C_GREEN}✅✅✅ UNINSTALL COMPLETE! ✅✅✅${C_NC}"
echo ""
echo "All configurations related to the session switcher have been removed."
echo -e "${C_YELLOW}A reboot is recommended to ensure all changes take effect.${C_NC}"
echo "Your system will now use the standard SDDM login screen."
echo "The main 'Hyprland' session option has been preserved."
echo ""
