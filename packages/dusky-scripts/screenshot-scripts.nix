{
  pkgs,
  dusky,
}: let
  # Upstream replaced dusky_screenshot.sh with the Rust dusky_snap (rust-apps.nix),
  # which has a different CLI. Our keybinds/rofi menu use this one's flags
  # (--freeze --annotate --tool), so keep the last upstream copy (40c1ed1) locally.
  scriptDir = ../../assets/scripts/screenshot;
in
  pkgs.symlinkJoin {
    name = "dusky-screenshot-scripts";
    paths = [
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-screenshot";
        runtimeInputs = with pkgs; [grim slurp satty wl-clipboard libnotify hyprland jq coreutils hyprpicker xdg-user-dirs];
        # slurp -d: live WxH readout while dragging (region/window/smart).
        text = builtins.replaceStrings ["$(slurp"] ["$(slurp -d"] (builtins.readFile (scriptDir + "/dusky_screenshot.sh"));
      })
    ];
  }
