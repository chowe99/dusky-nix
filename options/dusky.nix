{ lib, ... }:

{
  options.dusky = {
    gpu = {
      type = lib.mkOption {
        type = lib.types.enum [ "intel" "nvidia" "amd" "nvidia-passthrough" ];
        default = "intel";
        description = "Primary GPU type for driver configuration.";
      };
    };

    laptop = {
      enable = lib.mkEnableOption "laptop-specific features (power management, brightness, lid)";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [ "uwsm" "greetd" "none" ];
      default = "uwsm";
      description = "Display/session manager to use.";
    };

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "dusk";
        description = "Primary user account name.";
      };
      home = lib.mkOption {
        type = lib.types.str;
        default = "/home/dusk";
        description = "Home directory path.";
      };
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
      description = "Default terminal emulator.";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "firefox";
      description = "Default web browser.";
    };

  };
}
