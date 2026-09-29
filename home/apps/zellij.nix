{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: {
  # Deploy zellij config
  xdg.configFile."zellij" = {
    source = "${dusky}/.config/zellij";
    recursive = true;
  };

  # The app this config is for, unless the user already configures it.
  home.packages = lib.optional (!config.programs.zellij.enable) pkgs.zellij;
}
