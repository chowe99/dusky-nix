{ config, lib, pkgs, ... }:

let
  cfg = config.dusky.gpu;
in
{
  config = lib.mkIf (cfg.type == "nvidia-passthrough") {
    # VFIO / GPU passthrough for Looking Glass
    boot = {
      kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
      kernelParams = [
        "intel_iommu=on"
        "iommu=pt"
      ];
    };

    # Looking Glass shared memory
    systemd.tmpfiles.rules = [
      "f /dev/shm/looking-glass 0660 ${config.dusky.user.name} kvm -"
    ];

    environment.systemPackages = with pkgs; [
      looking-glass-client
    ];
  };
}
