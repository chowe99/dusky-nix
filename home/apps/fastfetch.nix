{ config, pkgs, lib, ... }:

{
  # Deploy fastfetch config
  xdg.configFile."fastfetch" = {
    source = ../../dusky/.config/fastfetch;
    recursive = true;
  };
}
