{ config, pkgs, ... }:

{
  # PipeWire audio stack
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # PulseAudio must be disabled when using PipeWire
  services.pulseaudio.enable = false;

  environment.systemPackages = with pkgs; [
    pamixer
    pulsemixer
  ];
}
