# checks/activation-order — regression test for the first-boot failure: the
# activation steps that read or fill around home-manager's links must run
# after linkGeneration. On a fresh home they used to run first, fail
# (createDefaultAnimation: no animations/dusky.lua yet) and abort activation.
# Reads the generated activate script, so no VM is needed.
#
#   nix build .#checks.x86_64-linux.will-activation-order -L
{
  pkgs,
  lib,
  nixosConfig,
  username,
}: let
  hm = nixosConfig.config.home-manager.users.${username};
  mustFollowLinks = ["createDefaultAnimation" "createHyprEditHere" "createWaybarSymlinks" "createMatugenGenerated"];
in
  # Hyprland writes its own hyprland.lua when it starts without one; that file
  # must not block the next activation.
  assert lib.assertMsg hm.xdg.configFile."hypr/hyprland.lua".force "hypr/hyprland.lua must be force-linked";
    pkgs.runCommand "dusky-activation-order-${username}" {} ''
      act=${hm.home.activationPackage}/activate
      line() { grep -n "_iNote \"Activating %s\" \"$1\"" "$act" | head -1 | cut -d: -f1; }
      links=$(line linkGeneration)
      [ -n "$links" ] || { echo "no linkGeneration step in $act"; exit 1; }
      fail=0
      for step in ${lib.escapeShellArgs mustFollowLinks}; do
        at=$(line "$step")
        if [ -z "$at" ]; then
          echo "missing activation step: $step"; fail=1
        elif [ "$at" -lt "$links" ]; then
          echo "$step runs before linkGeneration (line $at < $links)"; fail=1
        else
          echo "ok: $step after linkGeneration"
        fi
      done
      [ "$fail" = 0 ] && touch $out
    ''
