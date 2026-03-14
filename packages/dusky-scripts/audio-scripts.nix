{ pkgs, dusky }:

let
  scriptDir = ../../assets/scripts/audio;
in
pkgs.symlinkJoin {
  name = "dusky-audio-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-audio-switch";
      runtimeInputs = with pkgs; [ pulseaudio pamixer libnotify gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/audio_switch.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-mic-switch";
      runtimeInputs = with pkgs; [ pulseaudio pamixer libnotify gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/mic_switch.sh";
    })
    (pkgs.writeScriptBin "dusky-mono-audio" ''
      #!${pkgs.python3}/bin/python3
      ${builtins.readFile "${scriptDir}/mono_audio_pipewire.py"}
    '')
  ];
}
