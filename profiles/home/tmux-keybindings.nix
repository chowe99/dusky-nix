{
  config,
  lib,
  ...
}: {
  options.programs.tmux-keybindings = {
    copyMode = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Vi-style copy mode keybindings (defaults set by tmux-config)";
    };

    paneNavigation = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Pane selection/focus keybindings";
    };

    paneResize = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Pane resize keybindings";
    };

    paneSplit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Pane split keybindings";
    };

    paneSwap = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Pane swap keybindings (like SUPER+CTRL+HJKL in Hyprland)";
    };

    windowNavigation = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Window selection and management keybindings";
    };

    sessionControls = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Session management keybindings";
    };

    misc = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Other keybindings (reload, kill pane, etc.)";
    };

    extraBindings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra keybindings appended after all groups";
    };
  };

  # No config — tmux.nix sets variant-appropriate defaults and consumes these options
}
