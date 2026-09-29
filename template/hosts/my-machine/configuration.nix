{inputs, ...}: {
  imports = [
    # nixos-generate-config --show-hardware-config > hardware-configuration.nix
    ./hardware-configuration.nix
    inputs.self.nixosModules.standalone
  ];

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Snapper (profiles/nixos/common.nix) expects btrfs subvolumes for / and
  # /home; see hosts/will/INSTALL.md in dusky-nix for a full layout.

  system.stateVersion = "26.05";
}
