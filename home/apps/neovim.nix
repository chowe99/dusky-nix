{ config, pkgs, lib, ... }:

{
  # Deploy dusky_nvim config directory
  xdg.configFile."dusky_nvim" = {
    source = ../../dusky/.config/dusky_nvim;
    recursive = true;
  };
}
