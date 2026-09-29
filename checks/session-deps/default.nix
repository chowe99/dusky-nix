# checks/session-deps — fails if a command the deployed desktop configs launch
# by name (Hyprland exec_cmd, desktop entries, waybar, wlogout, hypridle,
# matugen post_hooks) is not installed on the evaluated system. See session.py.
#
#   nix build .#checks.x86_64-linux.will-session -L
{
  pkgs,
  nixosConfig,
  username,
}: let
  cfg = nixosConfig.config;
  hm = cfg.home-manager.users.${username};
  # Only a session's PATH: no baseline beyond what the system actually has.
  wrappers = builtins.attrNames cfg.security.wrappers;
in
  pkgs.runCommand "dusky-session-deps-audit-${username}" {
    nativeBuildInputs = [pkgs.python314 pkgs.shfmt];
  } ''
    printf '%s\n' ${pkgs.lib.escapeShellArgs wrappers} > baseline
    cp ${../runtime-deps/audit.py} audit.py
    cp ${./session.py} session.py
    python3 session.py \
      --shfmt ${pkgs.shfmt}/bin/shfmt \
      --home-files ${hm.home-files} \
      --bin ${cfg.system.path}/bin \
      --bin ${hm.home.path}/bin \
      --baseline baseline \
      --allow ${./allowlist}
    touch $out
  ''
