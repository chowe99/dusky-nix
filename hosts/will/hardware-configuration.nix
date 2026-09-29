# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  PLACEHOLDER — NOT GENERATED ON WILL'S HARDWARE.                          ║
# ║                                                                          ║
# ║  Replace this whole file with the output of, on the target machine:     ║
# ║      nixos-generate-config --root /mnt --show-hardware-config            ║
# ║  (see ./INSTALL.md). That fills in the real initrd modules, the LUKS     ║
# ║  device (by-uuid) and the btrfs mounts. Keep the subvol= options and     ║
# ║  add compress=zstd/noatime back if the generated file drops them.        ║
# ║                                                                          ║
# ║  As written it matches INSTALL.md's layout exactly, so it also boots:   ║
# ║    ESP  vfat  label BOOT              → /boot                           ║
# ║    LUKS2      partlabel cryptroot     → /dev/mapper/cryptroot           ║
# ║      btrfs    label nixos: @ → /, @home → /home, @nix → /nix            ║
# ╚══════════════════════════════════════════════════════════════════════════╝
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Broad set so an unknown laptop/desktop can reach the LUKS prompt
  # (NVMe/SATA/USB/SD storage, USB + I2C keyboards).
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "uas"
    "usbhid"
    "hid_generic"
    "sd_mod"
    "sdhci_pci"
    "rtsx_pci_sdmmc"
    "thunderbolt"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel" "kvm-amd"];
  boot.extraModulePackages = [];

  # LUKS2 container; unlocked by systemd initrd, prompt drawn by Plymouth.
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-partlabel/cryptroot";
    allowDiscards = true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@" "compress=zstd" "noatime"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd" "noatime"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
