#!/bin/bash

set -e

USER_NAME=$(whoami) USER_HOME=$(eval echo "~$USER_NAME") SESSION_SWITCHER="$USER_HOME/.xsession" SWITCH_SCRIPT="$USER_HOME/.local/bin/switch-session.sh"

STEP 1: Install dependencies

echo "==> Installing required packages..." sudo pacman -S --needed hyprland uwsm gamescope wofi sddm --noconfirm

STEP 2: Create Wayland session files

echo "==> Creating session files..."

Hyprland UWSM session

sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<EOF [Desktop Entry] Name=Hyprland (UWSM) Comment=Hyprland session managed by UWSM Exec=uwsm start hyprland Type=Application DesktopNames=Hyprland EOF

Gamescope session

sudo tee /usr/share/wayland-sessions/gamescope.desktop >/dev/null <<EOF [Desktop Entry] Name=Gamescope Session Comment=Gamescope fullscreen session (Steam-like) Exec=gamescope-session Type=Application DesktopNames=Gamescope EOF

Session switcher

sudo tee /usr/share/wayland-sessions/switcher.desktop >/dev/null <<EOF [Desktop Entry] Name=Auto Session Switcher Comment=Launches Hyprland or Gamescope based on last selection Exec=$SESSION_SWITCHER Type=Application EOF

STEP 3: Create launcher logic

echo "==> Creating session launcher logic..." cat > "$SESSION_SWITCHER" <<'EOS' #!/bin/bash

SESSION=$(cat "$HOME/.next-session" 2>/dev/null) rm -f "$HOME/.next-session"

if [[ "$SESSION" == "gamescope.desktop" ]]; then exec gamescope-session else exec uwsm start hyprland fi EOS

chmod +x "$SESSION_SWITCHER"

STEP 4: Create toggle script

echo "==> Creating switcher script..." mkdir -p "$USER_HOME/.local/bin"

cat > "$SWITCH_SCRIPT" <<'EOSWITCH' #!/bin/bash

choice=$(printf "Hyprland\nGamescope" | wofi --dmenu --prompt "Switch to:")

case "$choice" in Hyprland) echo "hyprland.desktop" > "$HOME/.next-session" ;; Gamescope) echo "gamescope.desktop" > "$HOME/.next-session" ;; *) exit 1 ;; esac

systemctl --user stop wayland-session.target EOSWITCH

chmod +x "$SWITCH_SCRIPT"

STEP 5: Configure Hyprland hotkey

echo "==> Configuring Hyprland keybind..." HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf" mkdir -p "$(dirname "$HYPR_CONF")" if ! grep -q 'switch-session.sh' "$HYPR_CONF" 2>/dev/null; then echo 'bind = SUPER, F12, exec, ~/.local/bin/switch-session.sh' >> "$HYPR_CONF" fi

STEP 6: Configure SDDM autologin

echo "==> Configuring SDDM autologin..." sudo mkdir -p /etc/sddm.conf.d sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<EOF [Autologin] User=$USER_NAME Session=switcher.desktop EOF

sudo tee /etc/sddm.conf.d/wayland.conf >/dev/null <<EOF [Wayland] Enable=true EOF

DONE

echo "==> Setup complete!" echo "➡️  Reboot your system to start the auto session switcher." echo "✅ Press SUPER+F12 inside Hyprland to switch to Gamescope (and vice versa)."

