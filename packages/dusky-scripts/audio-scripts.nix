{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/audio";
in
  pkgs.symlinkJoin {
    name = "dusky-audio-scripts";
    paths = [
      # Upstream renamed audio_switch.sh→dusky_output.sh, mic_switch.sh→dusky_input.sh
      # and moved from PulseAudio (pactl/pamixer) to WirePlumber (wpctl).
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-audio-switch";
        runtimeInputs = with pkgs; [wireplumber rofi libnotify gawk];
        text = builtins.readFile "${scriptDir}/dusky_output.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-mic-switch";
        runtimeInputs = with pkgs; [wireplumber rofi libnotify gawk];
        text = builtins.readFile "${scriptDir}/dusky_input.sh";
      })
      (pkgs.writeScriptBin "dusky-mono-audio" ''
        #!${pkgs.python3}/bin/python3
        ${builtins.readFile "${scriptDir}/mono_audio_pipewire.py"}
      '')
    ];
  }
