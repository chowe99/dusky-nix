{ config, lib, ... }:

let
  cfg = config.dusky.gpu;
in
{
  imports = [
    ./intel.nix
    ./nvidia.nix
    ./amd.nix
    ./nvidia-passthrough.nix
  ];

  # Hardware acceleration common to all GPUs
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
