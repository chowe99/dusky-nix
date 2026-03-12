{ config, pkgs, lib, ... }:

{
  # Deploy kitty.conf via xdg.configFile (not programs.kitty)
  # This preserves the matugen color include and raw config style
  xdg.configFile."kitty/kitty.conf".text = ''
    # Theme: matugen generated colors
    include ~/.config/matugen/generated/kitty-colors.conf

    # Fonts
    font_family      auto
    bold_font        auto
    italic_font      auto
    bold_italic_font auto
    font_size 12.0
    disable_ligatures never

    # Cursor
    cursor_shape beam
    cursor_blink_interval 0.5
    cursor_underline_thickness 4.0
    cursor_stop_blinking_after 2.0

    # Cursor trail
    cursor_trail 10
    cursor_trail_decay 0.15 0.4
    cursor_trail_start_threshold 2

    # Shell integration
    shell_integration no-cursor

    # Window
    hide_window_decorations yes
    confirm_os_window_close 0

    # Performance
    input_delay 3

    # Tabs
    tab_bar_edge top
    tab_bar_style powerline
    tab_powerline_style slanted
    tab_activity_symbol ⚡
    active_tab_font_style   bold
    inactive_tab_font_style normal

    # Keybindings
    map ctrl+shift+c copy_to_clipboard
    map ctrl+shift+v paste_from_clipboard
    map ctrl+shift+equal change_font_size all +2.0
    map ctrl+shift+minus change_font_size all -2.0
    map ctrl+shift+backspace change_font_size all 0
  '';
}
