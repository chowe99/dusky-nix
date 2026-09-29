# checks/runtime-deps — fails if a packaged dusky script invokes a command that
# is not in its own runtime closure. See audit.py for how "invokes" and
# "closure" are decided, and ./allowlist for the deliberate exceptions.
#
#   nix build .#checks.x86_64-linux.runtime-deps -L
{
  pkgs,
  packages,
}: let
  # What every NixOS system has on PATH without the host installing anything:
  # nixos/modules/config/system-path.nix requiredPackages (minus curl and
  # netcat, which scripts must declare), plus systemd/dbus/kmod/iproute2/iputils
  # from the base modules. Commands from here need no runtimeInputs entry.
  baselinePackages = with pkgs; [
    acl
    attr
    bashInteractive
    bzip2
    coreutils-full
    cpio
    diffutils
    findutils
    gawk
    getconf
    getent
    gnugrep
    gnupatch
    gnused
    gnutar
    gzip
    xz
    less
    libcap
    ncurses
    procps
    su
    time
    util-linux
    which
    zstd
    systemd
    dbus
    kmod
    iproute2
    iputils
    shadow
  ];
  python = pkgs.python314;
in
  pkgs.runCommand "dusky-runtime-deps-audit" {
    nativeBuildInputs = [python pkgs.shfmt];
  } ''
    for p in ${pkgs.lib.concatMapStringsSep " " (p: "${pkgs.lib.getBin p}") baselinePackages}; do
      [ -d "$p/bin" ] && ls "$p/bin"
    done | sort -u > baseline
    # setuid wrappers NixOS puts in /run/wrappers/bin
    printf '%s\n' sudo sudoedit visudo pkexec su mount umount fusermount fusermount3 newgrp sg passwd chsh ping >> baseline

    python3 ${./audit.py} \
      --shfmt ${pkgs.shfmt}/bin/shfmt \
      --baseline baseline \
      --allow ${./allowlist} \
      ${pkgs.lib.concatMapStringsSep " " (p: "${p}/bin") packages}
    touch $out
  ''
