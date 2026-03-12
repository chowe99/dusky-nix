{ config, lib, pkgs, ... }:

let
  cfg = config.dusky.gpu;
in
{
  config = lib.mkIf (cfg.type == "amd") {
    boot.initrd.kernelModules = [ "amdgpu" ];

    hardware.graphics.extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr.icd
    ];

    hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
      amdvlk
    ];

    environment.sessionVariables = {
      AMD_VULKAN_ICD = "RADV";
    };
  };
}
