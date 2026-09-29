# profiles/nixos/disk-snapshot.nix — nightly disk-usage snapshot for `dua`
#
# Runs as root so nothing is missed (a user-level walk silently under-reports
# /var), and writes one world-readable snapshot that `dusky-disk` imports
# instantly. See profiles/home/dusky-extras.nix for the reader.
#
# One root per drive: a second disk mounted at /mnt/data is a sibling of / in
# the view rather than a subtree of it, so the top level answers "which disk"
# before "which directory".
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dusky-desktop.diskSnapshot;

  ignoreArgs = lib.concatMapStringsSep " " (d: "-i ${lib.escapeShellArg d}") cfg.ignoreDirs;
  excludeLines = lib.concatMapStringsSep "\n" (m: "    ${m}") cfg.excludeMounts;

  snapshotScript = pkgs.writeShellScript "dua-snapshot" ''
        set -u
        PATH="${lib.makeBinPath [pkgs.dua pkgs.tmux pkgs.util-linux pkgs.coreutils pkgs.gawk]}"

        excludes=$(cat <<'EOF'
    ${excludeLines}
    EOF
        )

        # Real block devices only, deduped by base device so a bind mount or subvol
        # of a disk that is already a root does not become a second root. findmnt's
        # SOURCE carries the subvol in brackets — /dev/nvme0n1p2[/nix/store] — which
        # is exactly what makes the dedup possible.
        mapfile -t candidates < <(
          findmnt -rno TARGET,SOURCE |
            awk '$2 ~ /^\/dev\// { split($2, d, "["); if (!(d[1] in seen)) { seen[d[1]] = 1; print $1 } }' |
            sort -u
        )

        roots=()
        for m in "''${candidates[@]}"; do
          skip=""
          while read -r ex; do
            [ -n "$ex" ] || continue
            # Prefix match, so excluding /run/media drops every removable mount
            # under it without naming each one.
            case "$m" in "$ex"|"$ex"/*) skip=1; break ;; esac
          done <<< "$excludes"
          [ -n "$skip" ] || roots+=("$m")
        done

        if [ ''${#roots[@]} -eq 0 ]; then
          echo "dua-snapshot: no mounts left to scan after exclusions" >&2
          exit 1
        fi
        echo "dua-snapshot: roots: ''${roots[*]}"

        mkdir -p "$(dirname ${cfg.path})"
        tmp="${cfg.path}.new"
        rm -f "$tmp"

        # `dua interactive` refuses to start without a connected terminal, and
        # --export exists only on that subcommand (aggregate has --import but no
        # --export). `script` hands over a pty but nothing there answers the
        # cursor-position query, so dua dies with "cursor position could not be
        # read". tmux is a real terminal emulator and answers it. Private socket so
        # this never touches anyone's own tmux server.
        sock=/run/dua-snapshot.sock
        rm -f "$sock"
        tmux -S "$sock" new-session -d -s snap -x 200 -y 50 \
          "dua interactive --once --export '$tmp' -x ${ignoreArgs} ''${roots[*]}"
        while tmux -S "$sock" has-session -t snap 2>/dev/null; do sleep 5; done
        rm -f "$sock"

        if [ -s "$tmp" ]; then
          chmod 0644 "$tmp"
          mv -f "$tmp" ${cfg.path}
          echo "dua-snapshot: wrote ${cfg.path} ($(du -h ${cfg.path} | cut -f1))"
        else
          rm -f "$tmp"
          echo "dua-snapshot: traversal produced no snapshot" >&2
          exit 1
        fi
  '';
in {
  options.dusky-desktop.diskSnapshot = {
    enable = lib.mkEnableOption "nightly root-level dua disk-usage snapshot";

    path = lib.mkOption {
      type = lib.types.str;
      default = "/var/cache/dua/snapshot.dua";
      description = "Where the snapshot is written. Must be readable by the desktop user.";
    };

    excludeMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/boot" "/run/media"];
      example = ["/boot" "/run/media" "/mnt/data"];
      description = ''
        Mountpoints to leave out of the scan entirely, matched as prefixes — so
        "/run/media" drops every removable mount under it. Each remaining
        mountpoint becomes its own top-level entry in the snapshot.
      '';
    };

    ignoreDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/proc" "/dev" "/sys" "/run"];
      description = ''
        Directories skipped during traversal. Defaults cover the kernel
        pseudo-filesystems. Add network/FUSE mounts (a stat walk over them is
        slow) and any bind-mount trees that would otherwise be counted twice.
      '';
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:30:00";
      description = "systemd OnCalendar expression for the refresh.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = ["d ${builtins.dirOf cfg.path} 0755 root root -"];

    systemd.services.dua-snapshot = {
      description = "Refresh the dua disk-usage snapshot";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = snapshotScript;
        TimeoutStartSec = "90min";
        # A full walk is minutes of solid I/O — it must never compete with
        # anything interactive.
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.dua-snapshot = {
      description = "Refresh the dua disk-usage snapshot daily";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };

    # So `dusky-disk --refresh` can kick it off without a password prompt.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "dua-snapshot.service" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
