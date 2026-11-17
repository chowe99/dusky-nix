{
  pkgs,
  dusky,
}:
# Upstream replaced the bash screenshot tool, the bash waybar network meter and
# the GTK quick panel with these Rust apps. Upstream configs call them both by
# bare name and as $HOME/.local/bin/<name>; home/services links the latter.
# The control center (dusky_center) is in control-center.nix: it needs its
# config's paths rewritten.
let
  mk = import ./rust-lib.nix {inherit pkgs dusky;};
  dir = "${dusky}/user_scripts/dusky";
in
  pkgs.symlinkJoin {
    name = "dusky-rust-apps";
    paths = [
      (mk "dusky_snap" {})
      (mk "dusky_overview" {}) # workspace overview (keybinds.lua)
      # Waybar runs `dusky_network watch`; the shared sampler is
      # `dusky_network daemon` (user service in home/services).
      (mk "dusky_network" {})
      (mk "dusky_tray" {
        # Like the old quick panel, its default config and buttons call
        # ~/user_scripts/..., which NixOS doesn't have. ponytail: audio studio
        # and bluetooth_recovery.py aren't packaged; those buttons stay dead.
        postPatch = ''
          substituteInPlace dusky/dusky_tray/src/config.rs \
            --replace-fail "~/user_scripts/rofi/hypr_anim.sh" dusky-rofi-animations \
            --replace-fail "~/user_scripts/waybar/toggle_hypridle.sh" dusky-toggle-hypridle \
            --replace-fail "foot --app-id=dusky_tui python3 ~/user_scripts/dusky_tui/python/main/main.py ~/user_scripts/hypridle/tui_dusky_hypridle.py" \
                           "kitty --class dusky_tui -e dusky-tui ${dusky}/user_scripts/hypridle/tui_dusky_hypridle.py" \
            --replace-fail "~/user_scripts/hypr/hypr_blur_opacity_shadow_toggle.sh" dusky-blur-toggle \
            --replace-fail "~/user_scripts/rofi/shader_menu.sh" dusky-rofi-shader \
            --replace-fail "dusky-run kitty --class system_update.sh --hold sh -c '~/user_scripts/update_dusky/system_update.sh --all'" \
                           "dusky-nixos-ctl na 'Update declaratively: sudo nixos-rebuild switch --flake <your-flake>#<host>'" \
            --replace-fail "dusky-run kitty --class update_dusky.py --hold sh -c '~/user_scripts/update_dusky/python/update_dusky_supervisor.py'" \
                           "dusky-nixos-ctl na 'Update: nix flake update dusky-nix then rebuild'"
          substituteInPlace dusky/dusky_tray/src/ui.rs \
            --replace-fail "~/user_scripts/wlogout/wlogout_scale.sh" dusky-wlogout-scale \
            --replace-fail "foot --app-id=dusky_tui python3 ~/user_scripts/dusky_tui/python/main/main.py ~/user_scripts/network_manager/tui_dusky_network.py" \
                           "kitty --class dusky_tui -e dusky-network" \
            --replace-fail "~/user_scripts/audio/dusky_in_out_source.sh" dusky-audio-in-out
        '';
        # Read as fallbacks when ~/.local/share/dusky/dusky_tray/ has no copy.
        postInstall = ''
          install -Dm644 -t $out/share/dusky_tray ${dir}/dusky_tray/appearance.toml ${dir}/dusky_tray/ignored_apps.toml
        '';
      })
    ];
  }
