{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts";
  inherit (import ./tui-lib.nix {inherit pkgs dusky;}) mkTui;
in
  pkgs.symlinkJoin {
    name = "dusky-network-scripts";
    paths = [
      # Upstream replaced dusky_network.sh (gum) with a dusky_tui schema over
      # nmcli; the engine also reads iw/ip/ping and can show a QR for hotspots.
      (mkTui "dusky-network" "network_manager/tui_dusky_network.py"
        (with pkgs; [networkmanager iw iproute2 iputils qrencode wl-clipboard libnotify xdg-user-dirs]))
      # warp_toggle.sh was rewritten in Python (stdlib); warp-cli comes from
      # services.cloudflare-warp (allowlisted in checks/runtime-deps).
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-warp-toggle";
        runtimeInputs = with pkgs; [python3 libnotify systemd];
        text = ''exec python3 ${scriptDir}/networking/warp_toggle.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-arp-scan";
        runtimeInputs = with pkgs; [arp-scan coreutils gnugrep gawk];
        text = builtins.readFile "${scriptDir}/networking/arp_scan.sh";
      })
    ];
  }
