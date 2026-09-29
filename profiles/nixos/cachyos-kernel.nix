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
    # CachyOS kernel binary cache (maintainer's own attic). Pulls prebuilt
    # linux-cachyos-* instead of a from-source LTO compile — the `overlays.pinned`
    # variant is hash-matched to this cache. URL + key are from
    # nix-cachyos-kernel's own nixConfig.
    nix.settings.extra-substituters = ["https://attic.xuyh0120.win/lantian"];
    nix.settings.extra-trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];

    boot.kernelPackages = lib.mkDefault (
      if config.cachyos-kernel.enable
      then pkgs.cachyosKernels.linuxPackages-cachyos-latest
      else pkgs.linuxPackages_latest
    );
  };
}
