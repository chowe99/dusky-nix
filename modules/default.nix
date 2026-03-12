{ config, ... }:

{
  imports = [
    ./base.nix
    ./desktop.nix
    ./audio.nix
    ./networking.nix
    ./services.nix
    ./gpu
    ./laptop.nix
    ./virtualization.nix
  ];
}
