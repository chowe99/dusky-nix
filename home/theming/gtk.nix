{
  config,
  pkgs,
  lib,
  ...
}: {
  # The theme, icon theme and cursor the settings below (and matugen's gtk
  # post_hooks, and uwsm's XCURSOR_THEME) name. Adwaita + hicolor are the
  # fallbacks for the symbolic icon names the control center and waybar use
  # (image-x-generic-symbolic, ...): without an icon theme that has them,
  # they render as empty boxes.
  home.packages = with pkgs; [adw-gtk3 papirus-icon-theme bibata-cursors adwaita-icon-theme hicolor-icon-theme];

  # GTK 3 settings
  xdg.configFile."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=adw-gtk3
    gtk-icon-theme-name=Papirus
    gtk-font-name=Adwaita Sans 11
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=18
    gtk-toolbar-style=GTK_TOOLBAR_ICONS
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=0
    gtk-menu-images=0
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
  '';

  # GTK 4 settings
  xdg.configFile."gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=adw-gtk3
    gtk-icon-theme-name=Papirus
    gtk-font-name=Adwaita Sans 11
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=18
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
  '';

  # GTK CSS symlinks are managed by matugen post_hooks at runtime
}
