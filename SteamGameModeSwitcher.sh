
#!/bin/bash
#
# This script installs a complete, seamless session-switching environment
# for Hyprland and a Steam-based Gamescope session on Arch Linux.
# It includes an option for the user to enable or disable automatic login.
#

# Exit immediately if a command exits with a non-zero status.
set -e

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
echo -e "${C_BLUE} Hyprland <-> Gamescope Session Switcher Setup for user: ${C_YELLOW}$USER_NAME${C_NC}"
echo -e "${C_BLUE}===================================================================${C_NC}"
echo

# --- USER CHOICE FOR AUTOLOGIN ---
echo -e "${C_YELLOW}Configuration Choice:${C_NC}"
echo "This script can configure your system to automatically log in without a password for a seamless experience."
echo -e "NOTE: Autologin is a security risk if others have physical access to your computer."
read -p "Do you want to enable automatic login? [y/N]: " AUTOLOGIN_CHOICE
echo

# --- Script Variables ---
HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf"
SWITCH_SCRIPT_PATH="$USER_HOME/.local/bin/switch-session.sh"
XSESSION_PATH="$USER_HOME/.xsession"
SERVICE_OVERRIDE_DIR="/etc/systemd/user/gamescope-session-plus@.service.d"
SERVICE_OVERRIDE_FILE="$SERVICE_OVERRIDE_DIR/override.conf"

# Package lists
OFFICIAL_PACKAGES=( "hyprland" "wofi" "sddm" )
AUR_PACKAGES=( "gamescope" "gamescope-session-git" "gamescope-session-steam-git" )

#=======================================================
# STEP 1: DEPENDENCY INSTALLATION
#=======================================================
echo -e "${C_BLUE}==> Step 1: Installing Dependencies...${C_NC}"
if command -v yay &> /dev/null; then AUR_HELPER="yay"; elif command -v paru &> /dev/null; then AUR_HELPER="paru"; else
    echo -e "${C_RED}Error: No AUR helper found (yay or paru). Please install one and re-run this script.${C_NC}"; exit 1; fi
echo -e "${C_GREEN}Found AUR helper: ${AUR_HELPER}${C_NC}"
sudo pacman -Syu --needed "${OFFICIAL_PACKAGES[@]}" --noconfirm
$AUR_HELPER -S --needed "${AUR_PACKAGES[@]}" --noconfirm

#=======================================================
# STEP 2: CLEAN UP OLD CONFIGURATIONS
#=======================================================
echo -e "\n${C_BLUE}==> Step 2: Cleaning Up Any Old Configurations...${C_NC}"
sudo rm -f /etc/sddm.conf /etc/sddm.conf.d/autologin.conf
sudo rm -f /usr/share/wayland-sessions/{switcher,hyprland,gamescope,gamescope-steam,gamescope-session-steam}.desktop 2>/dev/null || true
rm -f "$XSESSION_PATH"
rm -f "$HOME/.local/bin/"switch-session.sh
sudo rm -rf "$SERVICE_OVERRIDE_DIR"
echo "-> Old configurations removed."

#=======================================================
# STEP 3: APPLY ROOT CAUSE FIX (SYSTEMD OVERRIDE)
#=======================================================
echo -e "\n${C_BLUE}==> Step 3: Applying Core Fix for the Wayland Socket Error...${C_NC}"
sudo mkdir -p "$SERVICE_OVERRIDE_DIR"
sudo tee "$SERVICE_OVERRIDE_FILE" > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/env -u WAYLAND_DISPLAY /usr/share/gamescope-session-plus/gamescope-session-plus %i
EOF
systemctl --user daemon-reload
echo "-> Systemd override for Gamescope created and reloaded."

#=======================================================
# STEP 4: INSTALL THE WORKFLOW
#=======================================================
echo -e "\n${C_BLUE}==> Step 4: Installing the Switching Workflow...${C_NC}"

# --- SDDM AUTOLOGIN (CONDITIONAL) ---
if [[ "$AUTOLOGIN_CHOICE" =~ ^[Yy]$ ]]; then
    echo "--> Configuring SDDM for automatic login..."
    sudo tee /etc/sddm.conf > /dev/null <<EOF
[Autologin]
User=${USER_NAME}
Session=switcher.desktop
Relogin=true
[Theme]
Current=
EOF
    AUTOLOGIN_ENABLED=true
else
    echo "--> Skipping autologin. Manual password entry will be required."
    AUTOLOGIN_ENABLED=false
fi

# --- WAYLAND SESSIONS ---
echo "--> Creating Wayland session files..."
# The switcher session (used by autologin or can be chosen manually)
sudo tee /usr/share/wayland-sessions/switcher.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Auto Session Switcher
Comment=Launches Hyprland or Gamescope based on last selection
Exec=${XSESSION_PATH}
Type=Application
EOF
# Fallback sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Exec=Hyprland
Type=Application
EOF
sudo tee /usr/share/wayland-sessions/gamescope-steam.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Gamescope (Steam)
Exec=gamescope-session-plus steam
Type=Application
EOF

# --- CORE LAUNCHER LOGIC & SWITCHER SCRIPT ---
echo "--> Creating user scripts..."
# Core logic
cat > "$XSESSION_PATH" <<'EOS'
#!/bin/bash
SESSION=$(cat "$HOME/.next-session" 2>/dev/null)
rm -f "$HOME/.next-session"
if [[ "$SESSION" == *"gamescope-session-steam"* ]]; then
    exec gamescope-session-plus steam
else
    exec Hyprland
fi
EOS
chmod +x "$XSESSION_PATH"

# Wofi switcher
mkdir -p "$(dirname "$SWITCH_SCRIPT_PATH")"
cat > "$SWITCH_SCRIPT_PATH" <<'EOSWITCH'
#!/bin/bash
choice=$(printf "Hyprland\nGamescope" | wofi --dmenu --prompt "Switch to:")
case "$choice" in
    Hyprland) echo "hyprland.desktop" > "$HOME/.next-session" ;;
    Gamescope) echo "gamescope-session-steam.desktop" > "$HOME/.next-session" ;;
    *) exit 1 ;;
esac
sleep 0.5
hyprctl dispatch exit
EOSWITCH
chmod +x "$SWITCH_SCRIPT_PATH"

# --- HYPRLAND HOTKEY ---
echo "--> Configuring Hyprland hotkey..."
mkdir -p "$(dirname "$HYPR_CONF")"
sed -i '/^bind = SUPER, F12/d' "$HYPR_CONF" 2>/dev/null || true
echo -e "\n# Switch between Gamescope and Hyprland" >> "$HYPR_CONF"
echo "bind = SUPER, F12, exec, $SWITCH_SCRIPT_PATH" >> "$HYPR_CONF"

#=======================================================
# FINALIZATION
#=======================================================
echo ""
echo -e "${C_GREEN}✅✅✅ SETUP COMPLETE! ✅✅✅${C_NC}"
echo ""
echo -e "${C_YELLOW}A reboot is required to apply all changes.${C_NC}"
echo ""
if [ "$AUTOLOGIN_ENABLED" = true ]; then
    echo -e "-> You have enabled ${C_GREEN}autologin${C_NC}. Your system will boot directly into Hyprland."
    echo    "   Press ${C_BLUE}SUPER+F12${C_NC} to switch sessions seamlessly."
else
    echo -e "-> You have chosen ${C_YELLOW}manual login${C_NC}. At the login screen, you must enter your password."
    echo    "   To switch sessions automatically, choose the ${C_BLUE}'Auto Session Switcher'${C_NC} from the session menu before logging in."
    echo    "   You can also log directly into Hyprland or Gamescope from this menu."
fi
echo ""
