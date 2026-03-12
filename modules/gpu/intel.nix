{ config, lib, pkgs, ... }:

let
  cfg = config.dusky.gpu;
in
{
  config = lib.mkIf (cfg.type == "intel") {
    # Intel GPU drivers
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver    # iHD driver (Broadwell+)
      vpl-gpu-rt            # Intel Video Processing Library
      intel-compute-runtime # OpenCL
    ];

    hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
    ];

    # Environment variable to prefer iHD driver
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
