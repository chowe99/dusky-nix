{ config, lib, pkgs, ... }:

let
  cfg = config.dusky.gpu;
in
{
  config = lib.mkIf (cfg.type == "nvidia" || cfg.type == "nvidia-passthrough") {
    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # Hybrid graphics (Intel + Nvidia) — PRIME offload
    hardware.nvidia.prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # These must be set per-host in hardware-configuration.nix
      # intelBusId = "PCI:0:2:0";
      # nvidiaBusId = "PCI:1:0:0";
    };

    environment.sessionVariables = {
      # Needed for Wayland on Nvidia
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
    };
  };
}
