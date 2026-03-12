{ pkgs }:

let
  scriptDir = ../../assets/scripts/audio;
in
pkgs.symlinkJoin {
  name = "dusky-audio-scripts";
  paths = [
    (pkgs.writeShellApplication {
      name = "dusky-audio-switch";
      runtimeInputs = with pkgs; [ pulseaudio pamixer libnotify gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/audio_switch.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-mic-switch";
      runtimeInputs = with pkgs; [ pulseaudio pamixer libnotify gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/mic_switch.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-mono-audio";
      runtimeInputs = with pkgs; [ python3 pipewire ];
      text = builtins.readFile "${scriptDir}/mono_audio_pipewire.py";
    })
  ];
}
