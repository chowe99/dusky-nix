# users/will/home.nix — Will: the dusky desktop, basics + opencode
{...}: {
  imports = [
    ../../profiles/home/standalone.nix
    ../../profiles/home/opencode.nix
  ];

  # dusky keybinding overrides (terminal on SUPER+T, arrow-key focus, …).
  programs.hyprland-keybindings.enable = true;
  programs.hyprland-keybindings.variant = "dusky";

  # Pull the latest config and switch to it (hosts/will/INSTALL.md §5).
  programs.zsh.shellAliases.update-system = "git -C ~/dusky-nix pull --ff-only && nixos-rebuild switch --sudo --flake ~/dusky-nix#will";
}
