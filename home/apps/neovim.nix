{ config, pkgs, lib, dusky, ... }:

{
  # Deploy dusky_nvim config directory
  xdg.configFile."dusky_nvim" = {
    source = "${dusky}/.config/dusky_nvim";
    recursive = true;
  };
}
