# profiles/home/package-set.nix — `packageSet` (the package set modules install
# from) and `cpu_architecture` options used by the other modules.
{
  pkgs,
  lib,
  ...
}: {
  options = {
    packageSet = lib.mkOption {
      type = lib.types.attrs;
      default = pkgs;
      description = "The package set to use for installing packages";
    };
    cpu_architecture = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.hostPlatform.system == "aarch64-linux"
        then "aarch64"
        else "x86_64";
      description = "CPU architecture for Flatpak and other tools";
    };
  };
}
