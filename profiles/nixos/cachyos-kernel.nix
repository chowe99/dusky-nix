# profiles/nixos/cachyos-kernel.nix — kernel choice + the CachyOS binary cache.
# `pkgs.cachyosKernels` comes from nix-cachyos-kernel's `overlays.pinned`
# (this flake's overlays.cachyos; lib.mkSystem adds it).
{
  config,
  pkgs,
  lib,
  ...
}: {
  options.cachyos-kernel.enable = lib.mkEnableOption "CachyOS optimized kernel (BORE scheduler, sched-ext, BBRv3, LTO)";

  config = {
    # No kernel binary cache (2026-10-18). The maintainer's attic
    # (https://attic.xuyh0120.win/lantian, key lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=)
    # now resolves to a private address, and an unreachable substituter makes every Nix build
    # fail, not just the kernel. Without a cache the kernel builds from source (~1h LTO) on each
    # bump; consumers can pin nix-cachyos-kernel to avoid that. Re-add the two
    # nix.settings.extra-* lines once attic is reachable again.

    boot.kernelPackages = lib.mkDefault (
      if config.cachyos-kernel.enable
      then pkgs.cachyosKernels.linuxPackages-cachyos-latest
      else pkgs.linuxPackages_latest
    );
  };
}
