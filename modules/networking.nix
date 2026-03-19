{ config, pkgs, lib, ... }:

{
  # Hostname
  networking.hostName = lib.mkDefault "dusky";

  # NetworkManager
  networking.networkmanager.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # Tailscale (optional, enable per-host)
  services.tailscale.enable = lib.mkDefault false;

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    iw
    wirelesstools
    wifitui
  ];
}
