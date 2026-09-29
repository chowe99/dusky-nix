{inputs, ...}: {
  imports = [
    inputs.self.homeManagerModules.standalone
    # inputs.self.homeManagerModules.opencode
  ];

  programs.hyprland-keybindings.enable = true;
  programs.hyprland-keybindings.variant = "dusky";
}
