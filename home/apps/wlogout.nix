{ config, pkgs, lib, ... }:

{
  # Wlogout layout with patched commands
  xdg.configFile."wlogout/layout".text = ''
    {
        "label": "lock",
        "action": "dusky-lock",
        "text": "Lock",
        "keybind": "l"
    }
    {
        "label": "logout",
        "action": "if uwsm check is-active; then uwsm stop; else hyprshutdown || hyprctl dispatch exit; fi",
        "text": "Logout",
        "keybind": "e"
    }
    {
        "label": "suspend",
        "action": "systemctl suspend",
        "text": "Suspend",
        "keybind": "u"
    }
    {
        "label": "shutdown",
        "action": "systemctl poweroff",
        "text": "Shutdown",
        "keybind": "s"
    }
    {
        "label": "soft-reboot",
        "action": "systemctl soft-reboot",
        "text": "Soft-Reboot",
        "keybind": "q"
    }
    {
        "label": "reboot",
        "action": "systemctl reboot",
        "text": "Reboot",
        "keybind": "r"
    }
  '';

  # Wlogout style (imports matugen colors)
  xdg.configFile."wlogout/style.css".source = ../../dusky/.config/wlogout/style.css;

  # Wlogout icons
  xdg.configFile."wlogout/icons" = {
    source = ../../dusky/.config/wlogout/icons;
    recursive = true;
  };
}
