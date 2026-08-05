{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: let
  # Upstream's ~/user_scripts/ tree, with packaged scripts symlinked to their
  # dusky-* binaries. Pointing `dusky_scripts` here is what lets us deploy
  # upstream's .lua config files verbatim instead of forking + sed-patching them.
  userScripts = "${pkgs.dusky.dusky-user-scripts}/user_scripts/";

  upstreamHypr = "${dusky}/.config/hypr";
in {
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ./hyprsunset.nix
  ];

  # Main config. Hyprland 0.55+ dropped hyprlang for Lua; .conf support is gone
  # in 0.57. This mirrors upstream's hyprland.lua, but resolves scripts through
  # the Nix shim tree rather than $HOME/user_scripts.
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- -----------------------------------------------------
    -- HYPRLAND MAIN CONFIGURATION
    -- Managed by Nix / home-manager
    -- System: UWSM Managed
    -- -----------------------------------------------------
    -- Files are loaded with require(); Hyprland gives each one its own
    -- error-isolated scope, so a broken file won't abort the rest.
    -- Paths are dot-separated, relative to ~/.config/hypr/.

    HOME = os.getenv("HOME")

    -- Nix-packaged dusky scripts (upstream uses HOME .. "/user_scripts/")
    dusky_scripts = "${userScripts}"

    -- Matugen palette. Written by matugen at theme-switch time, so it may not
    -- exist on a fresh install — loadfile keeps that from aborting the config.
    do
      local colors = loadfile(HOME .. "/.config/matugen/generated/hyprland-colors.lua")
      if colors then colors() end
    end

    -- User variables ($terminal, $browser, ...) must come first: every file
    -- below reads them as globals.
    require("edit_here.source.default_apps")

    require("source.monitors")
    require("source.permissions")
    require("source.input")
    require("source.appearance")
    require("source.window_rules")
    require("source.keybinds")
    require("source.autostart")
    require("source.environment_variables")
    require("source.workspace_rules")

    -- dusky-nix deltas on top of upstream (settings, extra binds, extra rules).
    require("source.dusky-nix")

    -- Local overrides — loaded LAST so it can unbind/replace anything above.
    require("edit_here.hyprland")
  '';

  # Upstream .lua config, deployed verbatim. Script paths resolve via the shim
  # tree above, so these need no patching and future dusky syncs are free.
  xdg.configFile."hypr/source/appearance.lua".source = lib.mkDefault "${upstreamHypr}/source/appearance.lua";
  xdg.configFile."hypr/source/autostart.lua".source = lib.mkDefault "${upstreamHypr}/source/autostart.lua";
  xdg.configFile."hypr/source/environment_variables.lua".source = lib.mkDefault "${upstreamHypr}/source/environment_variables.lua";
  xdg.configFile."hypr/source/input.lua".source = lib.mkDefault "${upstreamHypr}/source/input.lua";
  xdg.configFile."hypr/source/keybinds.lua".source = lib.mkDefault "${upstreamHypr}/source/keybinds.lua";
  xdg.configFile."hypr/source/monitors.lua".source = lib.mkDefault "${upstreamHypr}/source/monitors.lua";
  xdg.configFile."hypr/source/permissions.lua".source = lib.mkDefault "${upstreamHypr}/source/permissions.lua";
  xdg.configFile."hypr/source/window_rules.lua".source = lib.mkDefault "${upstreamHypr}/source/window_rules.lua";
  xdg.configFile."hypr/source/workspace_rules.lua".source = lib.mkDefault "${upstreamHypr}/source/workspace_rules.lua";

  # Our deltas on top of upstream — see the file header for what belongs here.
  xdg.configFile."hypr/source/dusky-nix.lua".source = lib.mkDefault ./source/dusky-nix.lua;

  # Deploy animation presets
  xdg.configFile."hypr/source/animations" = {
    source = lib.mkDefault "${upstreamHypr}/source/animations";
    recursive = true;
  };

  # Deploy shaders
  xdg.configFile."hypr/shaders" = {
    source = lib.mkDefault "${upstreamHypr}/shaders";
    recursive = true;
  };

  # Deploy hyprlock themes (patched: replace ~/user_scripts/ paths with Nix-packaged names)
  # hyprlock is still hyprlang — only Hyprland itself moved to Lua.
  xdg.configFile."hypr/hyprlock_themes" = {
    source = lib.mkDefault (pkgs.runCommand "dusky-hyprlock-themes-patched" {} ''
      cp -r "${upstreamHypr}/hyprlock_themes" $out
      chmod -R u+w $out
      find $out -name '*.conf' -exec sed -i \
        -e 's|~/user_scripts/hyprlock/check_capslock.sh|dusky-hyprlock-capslock|g' \
        -e 's|~/user_scripts/hyprlock/battery_status.sh|dusky-hyprlock-battery|g' \
        {} +
    '');
    recursive = true;
  };

  # UWSM is required for dusky's keybinds, desktop entries, and autostart commands
  # tesseract is required for dusky's OCR keybinds (SUPER+T, SUPER+SHIFT+T)
  home.packages = [pkgs.uwsm pkgs.tesseract];

  # Create mutable edit_here directory structure via activation
  home.activation.createHyprEditHere = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$HOME/.config/hypr/edit_here/source"
        # Create default files if they don't exist
        if [ ! -f "$HOME/.config/hypr/edit_here/hyprland.lua" ]; then
          run touch "$HOME/.config/hypr/edit_here/hyprland.lua"
        fi
        if [ ! -f "$HOME/.config/hypr/edit_here/source/default_apps.lua" ]; then
          cat > "$HOME/.config/hypr/edit_here/source/default_apps.lua" << 'LUA'
    -- User-editable default apps. Globals, so source/keybinds.lua can read them.
    terminal    = "kitty"
    fileManager = "yazi"
    menu        = "rofi -show drun"
    browser     = "firefox"
    textEditor  = "nvim"
    LUA
        fi
  '';

  # Create default animation preset if none is active
  home.activation.createDefaultAnimation = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.config/hypr/source/animations/active"
    if [ ! -f "$HOME/.config/hypr/source/animations/active/active.lua" ]; then
      run cp "$HOME/.config/hypr/source/animations/dusky.lua" \
             "$HOME/.config/hypr/source/animations/active/active.lua"
    fi
  '';
}
