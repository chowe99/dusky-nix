{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/audio";

  # Upstream merged dusky_output.sh + dusky_input.sh into one rofi menu,
  # dusky_in_out_source.sh --output|--input (WirePlumber, also lists virtual nodes).
  inOut = pkgs.writeShellApplication {
    checkPhase = "";
    name = "dusky-audio-in-out";
    runtimeInputs = with pkgs; [wireplumber pipewire rofi libnotify gawk];
    text = builtins.readFile "${scriptDir}/dusky_in_out_source.sh";
  };
in
  pkgs.symlinkJoin {
    name = "dusky-audio-scripts";
    paths = [
      inOut
      # The old names stay: desktop entries and control-center rows call them.
      (pkgs.writeShellScriptBin "dusky-audio-switch" ''exec ${inOut}/bin/dusky-audio-in-out --output "$@"'')
      (pkgs.writeShellScriptBin "dusky-mic-switch" ''exec ${inOut}/bin/dusky-audio-in-out --input "$@"'')
      (pkgs.writeScriptBin "dusky-mono-audio" ''
        #!${pkgs.python3}/bin/python3
        ${builtins.readFile "${scriptDir}/mono_audio_pipewire.py"}
      '')
    ];
  }
