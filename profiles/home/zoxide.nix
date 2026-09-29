{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true; # Add this to enable Zsh completion
    options = [
      "--cmd cd" # Ensure zoxide uses 'cd' as the command (matches your alias cd="z")
    ];
  };
}
