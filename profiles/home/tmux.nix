{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.tmux-config;
  keyCfg = config.programs.tmux-keybindings;

  # Concatenate all keybinding groups into a single block
  allKeybindings = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
    keyCfg.copyMode
    keyCfg.paneSplit
    keyCfg.paneNavigation
    keyCfg.paneResize
    keyCfg.paneSwap
    keyCfg.windowNavigation
    keyCfg.sessionControls
    keyCfg.misc
    keyCfg.extraBindings
  ]);
in {
  imports = [
    ./tmux-keybindings.nix
  ];

  options.programs.tmux-config = {
    enable = lib.mkEnableOption "tmux configuration";

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra tmux config appended after everything else";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # ── Unified keybindings (shared across all variants) ──
    {
      programs.tmux-keybindings = {
        copyMode = lib.mkDefault ''
          # ── Vi mode ──
          bind -T copy-mode-vi v send -X begin-selection
          bind -T copy-mode-vi y send -X copy-selection-and-cancel
          bind -T copy-mode-vi C-v send -X rectangle-toggle
        '';

        paneSplit = lib.mkDefault ''
          # ── Pane splits ──
          bind h split-window -v -c "#{pane_current_path}"
          bind v split-window -h -c "#{pane_current_path}"
          bind x kill-pane
        '';

        paneNavigation = lib.mkDefault ''
          # ── Pane navigation ──
          bind -n C-M-Left select-pane -L
          bind -n C-M-Right select-pane -R
          bind -n C-M-Up select-pane -U
          bind -n C-M-Down select-pane -D
        '';

        paneResize = lib.mkDefault ''
          # ── Pane resize ──
          bind -n C-M-S-Left resize-pane -L 5
          bind -n C-M-S-Down resize-pane -D 5
          bind -n C-M-S-Up resize-pane -U 5
          bind -n C-M-S-Right resize-pane -R 5
        '';

        paneSwap = lib.mkDefault ''
          # ── Pane swap ──
          bind C-Left swap-pane -s '{left-of}'
          bind C-Down swap-pane -s '{down-of}'
          bind C-Up swap-pane -s '{up-of}'
          bind C-Right swap-pane -s '{right-of}'
        '';

        windowNavigation = lib.mkDefault ''
          # ── Window navigation ──
          bind r command-prompt -I "#W" "rename-window -- '%%'"
          bind c new-window -c "#{pane_current_path}"
          bind k kill-window

          bind -n M-1 select-window -t 1
          bind -n M-2 select-window -t 2
          bind -n M-3 select-window -t 3
          bind -n M-4 select-window -t 4
          bind -n M-5 select-window -t 5
          bind -n M-6 select-window -t 6
          bind -n M-7 select-window -t 7
          bind -n M-8 select-window -t 8
          bind -n M-9 select-window -t 9
          bind -n M-Left select-window -t -1
          bind -n M-Right select-window -t +1
          bind -n M-S-Left swap-window -t -1 \; select-window -t -1
          bind -n M-S-Right swap-window -t +1 \; select-window -t +1
        '';

        sessionControls = lib.mkDefault ''
          # ── Session controls ──
          bind R command-prompt -I "#S" "rename-session -- '%%'"
          bind C new-session -c "#{pane_current_path}"
          bind K kill-session
          bind P switch-client -p
          bind N switch-client -n
          bind -n M-Up switch-client -p
          bind -n M-Down switch-client -n
        '';

        misc = lib.mkDefault ''
          # Reload config
          bind q source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

          # Unbind C-\ (vim-tmux-navigator default) to avoid conflict with nvim
          unbind -n C-\\
        '';
      };
    }

    # ── programs.tmux module (catppuccin theme) ──
    {
      programs.tmux = {
        enable = true;
        keyMode = "vi";
        clock24 = true;
        baseIndex = 1;
        escapeTime = 0;
        historyLimit = 50000;
        newSession = true;
        terminal = "tmux-256color";
        aggressiveResize = true;
        resizeAmount = 5;

        plugins = with pkgs.tmuxPlugins; [
          sensible
          yank
          resurrect
          {
            plugin = continuum;
            extraConfig = ''
              set -g @continuum-restore 'on'
              set -g @continuum-save-interval '10'
            '';
          }
          vim-tmux-navigator
          {
            plugin = tmux-which-key;
            extraConfig = ''
              set -g @tmux-which-key-xdg-enable 1
              set -g @tmux-which-key-disable-autobuild 1
            '';
          }
        ];

        extraConfig =
          ''
            # ── Prefix ──
            unbind C-b
            set -g prefix C-Space
            set -g prefix2 C-b
            bind C-Space send-prefix

            # ── General ──
            set -ag terminal-overrides ",*:RGB"
            set -g mouse on
            setw -g pane-base-index 1
            set -g renumber-windows on
            set -g focus-events on
            set -g set-clipboard on
            set -g allow-passthrough on
            set -g detach-on-destroy off

            # ── Status bar ──
            set -g status-position top
            set -g status-interval 5
            set -g status-left-length 30
            set -g status-right-length 50
            set -g window-status-separator ""
            set -gw automatic-rename on
            set -gw automatic-rename-format '#{b:pane_current_path}'

            # ── Theme ──
            set -g status-style "bg=default,fg=default"
            set -g status-left "#[fg=black,bg=blue,bold] #S #[bg=default] "
            set -g status-right "#[fg=blue]#{?client_prefix,PREFIX ,}#[fg=brightblack]#h "
            set -g window-status-format "#[fg=brightblack] #I:#W "
            set -g window-status-current-format "#[fg=blue,bold] #I:#W "
            set -g pane-border-style "fg=brightblack"
            set -g pane-active-border-style "fg=blue"
            set -g message-style "bg=default,fg=blue"
            set -g message-command-style "bg=default,fg=blue"
            set -g mode-style "bg=blue,fg=black"
            setw -g clock-mode-colour blue

            ${allKeybindings}
          ''
          + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";
      };
    }
  ]);
}
