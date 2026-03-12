{ config, pkgs, ... }:

{
  # ZRAM swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Logrotate
  services.logrotate.enable = true;

  # Fstrim for SSDs
  services.fstrim.enable = true;

  # Udev rules
  services.udev.extraRules = ''
    # Allow users in "video" group to control backlight
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
}
