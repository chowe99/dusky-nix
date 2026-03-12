{ config, lib, pkgs, ... }:

let
  cfg = config.dusky.laptop;
in
{
  config = lib.mkIf cfg.enable {
    # TLP for power management
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };

    # Power profiles daemon conflicts with TLP
    services.power-profiles-daemon.enable = false;

    # Lid close behavior
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "lock";
    };

    environment.systemPackages = with pkgs; [
      powertop
      acpi
    ];
  };
}
