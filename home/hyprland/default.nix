{ config, pkgs, lib, dusky, ... }:

let
  hyprDir = ./.;
in
{
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ./hyprsunset.nix
  ];

  # Deploy the main hyprland.conf
  xdg.configFile."hypr/hyprland.conf".text = ''
    source = ~/.config/hypr/edit_here/source/default_apps.conf


    # -----------------------------------------------------
    # HYPRLAND MAIN CONFIGURATION
    # -----------------------------------------------------
    # Managed by Nix / home-manager
    # System: UWSM Managed
    # -----------------------------------------------------

    # 1. MONITORS
    source = ~/.config/hypr/source/monitors.conf

    # 2. PERMISSIONS
    source = ~/.config/hypr/source/permissions.conf

    # 3. INPUT DEVICES
    source = ~/.config/hypr/source/input.conf

    # 4. APPEARANCE
    source = ~/.config/hypr/source/appearance.conf

    # 5. WINDOW RULES
    source = ~/.config/hypr/source/window_rules.conf

    # 6. KEYBINDINGS
    source = ~/.config/hypr/source/keybinds.conf

    # 7. AUTOSTART
    source = ~/.config/hypr/source/autostart.conf

    # 8. ENVIRONMENT VARIABLES
    source = ~/.config/hypr/source/environment_variables.conf

    # 9. WORKSPACE RULES
    source = ~/.config/hypr/source/workspace_rules.conf

    # -----------------------------------------------------
    # LOCAL OVERRIDES (User editable, not Nix-managed)
    # -----------------------------------------------------
    source = ~/.config/hypr/edit_here/hyprland.conf
  '';

  # Deploy source/*.conf files
  # Unpatched configs reference dusky/ submodule directly (upstream updates flow through)
  # Patched configs (autostart, keybinds) live in this repo with dusky-* script name translations
  xdg.configFile."hypr/source/appearance.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/appearance.conf";
  xdg.configFile."hypr/source/autostart.conf".source = lib.mkDefault ./source/autostart.conf;
  xdg.configFile."hypr/source/environment_variables.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/environment_variables.conf";
  xdg.configFile."hypr/source/input.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/input.conf";
  xdg.configFile."hypr/source/keybinds.conf".source = lib.mkDefault ./source/keybinds.conf;
  xdg.configFile."hypr/source/monitors.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/monitors.conf";
  xdg.configFile."hypr/source/permissions.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/permissions.conf";
  xdg.configFile."hypr/source/window_rules.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/window_rules.conf";
  xdg.configFile."hypr/source/workspace_rules.conf".source = lib.mkDefault "${dusky}/.config/hypr/source/workspace_rules.conf";

  # Deploy animation presets
  xdg.configFile."hypr/source/animations" = {
    source = lib.mkDefault "${dusky}/.config/hypr/source/animations";
    recursive = true;
  };

  # Deploy shaders
  xdg.configFile."hypr/shaders" = {
    source = lib.mkDefault "${dusky}/.config/hypr/shaders";
    recursive = true;
  };

  # Deploy hyprlock themes
  xdg.configFile."hypr/hyprlock_themes" = {
    source = lib.mkDefault "${dusky}/.config/hypr/hyprlock_themes";
    recursive = true;
  };

  # Create mutable edit_here directory structure via activation
  home.activation.createHyprEditHere = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/hypr/edit_here/source"
    # Create default files if they don't exist
    if [ ! -f "$HOME/.config/hypr/edit_here/hyprland.conf" ]; then
      run touch "$HOME/.config/hypr/edit_here/hyprland.conf"
    fi
    if [ ! -f "$HOME/.config/hypr/edit_here/source/default_apps.conf" ]; then
      cat > "$HOME/.config/hypr/edit_here/source/default_apps.conf" << 'CONF'
# User-editable default apps
# These variables are used throughout keybinds.conf
$terminal    = kitty
$fileManager = yazi
$menu        = rofi -show drun
$browser     = firefox
$textEditor  = nvim
CONF
    fi
  '';
}
