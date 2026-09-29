# profiles/home/standalone.nix — a complete dusky desktop user (home side):
# common.nix + kitty, zsh (plugins, fzf-tab, vi-mode), fzf/zoxide/fastfetch,
# tmux and the dusky keybinding overrides, plus Zen, Thunar and btop. The
# dusky app configs themselves (neovim, rofi, yazi, zathura, cava, mpv,
# zellij, zed, ...) come from lib.mkSystem's `apps`.
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    ./package-set.nix
    ./zsh.nix
    ./kitty.nix
    ./fastfetch.nix
    ./zoxide.nix
    ./fzf.nix
    ./fd.nix
    ./ripgrep.nix
    ./tmux.nix
    ./hyprland-keybindings.nix
    ./common.nix
  ];

  # tmux (SUPER+ALT+RETURN opens it).
  programs.tmux-config.enable = true;

  home.stateVersion = "26.05";
  home.username = username;
  home.homeDirectory = "/home/${username}";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    dusky.dusky-scripts-all
    # Browser (zen-transparency seeds its theme)
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    # GUI file manager (yazi is the TUI one, from dusky's NixOS module)
    thunar
    thunar-archive-plugin
    xarchiver
    btop # SUPER+SHIFT+T and the menu's "Activity"
    lsd # zsh's ls aliases
    # SUPER+SHIFT+N. `nix` itself is the host's.
    (writeShellScriptBin "nix-search" ''
      export PATH="${lib.makeBinPath [fzf libnotify uwsm wl-clipboard xdg-terminal-exec]}:$PATH"
      ${builtins.readFile ../scripts/nix-search}
    '')
  ];

  # Default apps. Globals — dusky's source/keybinds.lua reads them.
  xdg.configFile."hypr/edit_here/source/default_apps.lua".text = ''
    terminal    = "kitty"
    fileManager = "yazi"
    menu        = "rofi -show drun"
    browser     = "zen-beta"
    textEditor  = "nano"
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/terminal" = "kitty.desktop";
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "inode/directory" = "thunar.desktop";
      "application/zip" = "xarchiver.desktop";
      "application/x-7z-compressed" = "xarchiver.desktop";
      "application/x-tar" = "xarchiver.desktop";
      "application/gzip" = "xarchiver.desktop";
      "application/x-compressed-tar" = "xarchiver.desktop";
      "application/x-xz-compressed-tar" = "xarchiver.desktop";
    };
  };

  # Thunar's "Open Terminal Here"
  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
  '';

  # The always-listening voice assistant (an OpenRouter agent with a
  # hard-coded search endpoint): not started at login. SUPER+I/O TTS/STT
  # still work on demand.
  systemd.user.services.dusky-voice-assistant.Install.WantedBy = lib.mkForce [];

  # awww-daemon is started by the Hyprland autostart (profiles/home/common.nix),
  # once the compositor is up. A graphical-session.target unit started it
  # before WAYLAND_DISPLAY reached the user manager and crash-looped at login.
}
