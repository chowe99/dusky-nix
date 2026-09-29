{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.hyprland-keybindings;
  inherit (lib.generators) mkLuaInline;

  # hl.bind(keys, dispatcher [, opts]) — raw Lua so binds can reference the
  # locals declared by the Hyprland config (mainMod, terminal, ...).
  mkBind = keys: dsp: {_args = [(mkLuaInline keys) (mkLuaInline dsp)];};
  mkBindOpts = keys: dsp: opts: {_args = [(mkLuaInline keys) (mkLuaInline dsp) opts];};
in {
  options.programs.hyprland-keybindings = {
    enable = lib.mkEnableOption "Hyprland keybindings management";

    variant = lib.mkOption {
      type = lib.types.enum ["standalone" "dusky"];
      default = "standalone";
      description = ''
        Keybinding variant:
        - standalone: Adds keybindings to wayland.windowManager.hyprland.settings.bind
        - dusky: Writes ~/.config/hypr/edit_here/hyprland.lua with override unbinds + rebinds
      '';
    };

    extraBinds = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
      default = [];
      description = "Extra keybindings to merge into settings.bind (standalone variant only)";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra Lua appended to edit_here/hyprland.lua (dusky variant only)";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf (cfg.variant == "standalone") {
      wayland.windowManager.hyprland.settings.bind =
        [
          (mkBind ''mainMod .. " + N"'' ''hl.dsp.exec_cmd("kitty --title nix-search nix-search")'')
          # Vim-style move window bindings
          (mkBind ''mainMod .. " + CTRL + H"'' ''hl.dsp.window.move({ direction = "l" })'')
          (mkBind ''mainMod .. " + CTRL + L"'' ''hl.dsp.window.move({ direction = "r" })'')
          (mkBind ''mainMod .. " + CTRL + K"'' ''hl.dsp.window.move({ direction = "u" })'')
          (mkBind ''mainMod .. " + CTRL + J"'' ''hl.dsp.window.move({ direction = "d" })'')
          # Resize (hyprlang's binde == the `repeating` bind option in Lua)
          (mkBindOpts ''mainMod .. " + ALT + left"'' ''hl.dsp.window.resize({ x = -20, y = 0, relative = true })'' {repeating = true;})
          (mkBindOpts ''mainMod .. " + ALT + right"'' ''hl.dsp.window.resize({ x = 20, y = 0, relative = true })'' {repeating = true;})
          (mkBindOpts ''mainMod .. " + ALT + up"'' ''hl.dsp.window.resize({ x = 0, y = -20, relative = true })'' {repeating = true;})
          (mkBindOpts ''mainMod .. " + ALT + down"'' ''hl.dsp.window.resize({ x = 0, y = 20, relative = true })'' {repeating = true;})
        ]
        ++ cfg.extraBinds;
      wayland.windowManager.hyprland.settings.window_rule = [
        {
          name = "nix-search";
          match.title = "^nix-search$";
          float = true;
          size = "800 600";
          center = true;
        }
      ];
    })

    (lib.mkIf (cfg.variant == "dusky") {
      # `ocr` for the CTRL+ALT+T bind below.
      home.packages = [pkgs.rust-paddle-ocr];
      xdg.configFile."hypr/edit_here/hyprland.lua".force = true;
      xdg.configFile."hypr/edit_here/hyprland.lua".text =
        ''
          -- Nix-managed overrides — required last by Dusky's hyprland.lua
          -- Only unbinds + rebinds that differ from Dusky defaults
          -- Dusky features preserved: SUPER+hjkl (focus), SUPER+M (lock),
          --   SUPER+I (STT Parakeet), SUPER+O (TTS Kokoro), SUPER+S (screenshot),
          --   SUPER+V (clipboard), SUPER+B (color picker), ALT+SPACE (rofi), etc.

          -- Unbind Dusky defaults we're overriding
          hl.unbind("SUPER + T")        -- dusky: OCR Selection → ours: Terminal
          hl.unbind("SUPER + SHIFT + T")-- dusky: OCR Fullscreen → ours: btop
          hl.unbind("SUPER + N")        -- rebind with searchable description
          -- SUPER+Z/SHIFT+Z: keep dusky defaults (Scratchpad)

          -- Dusky's vim-style SUPER+hjkl (focus) and SUPER+SHIFT+hjkl (move) are
          -- deliberately LEFT ALONE — they don't collide with the arrow-key binds
          -- below, and unbinding them (as this file used to) just made SUPER+K
          -- silently dead.

          -- Override dusky
          for _, k in ipairs({ "left", "right", "up", "down" }) do
              hl.unbind("SUPER + " .. k)
          end

          -- Focus movement (arrow keys)
          hl.bind("SUPER + left",  hl.dsp.focus({ direction = "left" }),  { repeating = true, description = "Focus Left" })
          hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }), { repeating = true, description = "Focus Right" })
          hl.bind("SUPER + up",    hl.dsp.focus({ direction = "up" }),    { repeating = true, description = "Focus Up" })
          hl.bind("SUPER + down",  hl.dsp.focus({ direction = "down" }),  { repeating = true, description = "Focus Down" })

          -- Window movement (arrow keys)
          hl.bind("SUPER + SHIFT + left",  hl.dsp.window.move({ direction = "l" }), { repeating = true, description = "Move Left" })
          hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { repeating = true, description = "Move Right" })
          hl.bind("SUPER + SHIFT + up",    hl.dsp.window.move({ direction = "u" }), { repeating = true, description = "Move Up" })
          hl.bind("SUPER + SHIFT + down",  hl.dsp.window.move({ direction = "d" }), { repeating = true, description = "Move Down" })

          -- Window resize (arrow keys)
          hl.bind("SUPER + ALT + left",  hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true })
          hl.bind("SUPER + ALT + right", hl.dsp.window.resize({ x = 20,  y = 0,   relative = true }), { repeating = true })
          hl.bind("SUPER + ALT + up",    hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true })
          hl.bind("SUPER + ALT + down",  hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true })

          -- Terminal (replaces dusky OCR on SUPER+T). Deliberately not the
          -- `terminal` global from default_apps — this one honours xdg-terminal-exec.
          local xdgTerminal = "uwsm-app -- xdg-terminal-exec"
          hl.bind("SUPER + T", hl.dsp.exec_cmd(xdgTerminal), { description = "Terminal" })

          -- Custom bindings
          hl.bind("SUPER + N",           hl.dsp.exec_cmd("uwsm-app -- dusky-rofi-mako"), { description = "Notification Center" })
          hl.bind("SUPER + SHIFT + N",   hl.dsp.exec_cmd("uwsm-app -- xdg-terminal-exec --title=nix-search nix-search"), { description = "Nix package search" })
          hl.bind("SUPER + SHIFT + T",   hl.dsp.exec_cmd("uwsm-app -- xdg-terminal-exec --class btop -e btop"), { description = "Activity (btop)" })
          hl.bind("SUPER + ALT + RETURN", hl.dsp.exec_cmd("uwsm-app -- xdg-terminal-exec tmux new"), { description = "Tmux" })

          -- Float nix-search window centered
          hl.window_rule({
              name  = "nix-search",
              match = { title = "^nix-search$" },
              float  = true,
              size   = "800 600",
              center = true,
          })

          -- OCR (PaddleOCR via rust-paddle-ocr) — select region, extract text to clipboard
          hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd([[pgrep -x ocr || (f=$(mktemp).png; slurp | grim -g - "$f" && ocr -p "$f" | wl-copy; rm -f "$f")]]), { description = "OCR Selection" })

          -- Screenshots (using dusky's screenshot tool)
          hl.bind("CTRL + ALT + S",         hl.dsp.exec_cmd("dusky-screenshot --region --freeze --no-notify"), { description = "OCR Screenshot" })
          hl.bind("CTRL + ALT + SHIFT + S", hl.dsp.exec_cmd("dusky-screenshot --region --freeze --annotate --no-notify --tool arrow"), { description = "Screenshot (annotate)" })
        ''
        + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";
    })
  ]);
}
