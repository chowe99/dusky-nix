# Shared by the packages that run upstream dusky_tui schemas (tui_*.py).
#
# Upstream moved most settings screens into a textual/rich TUI framework at
# user_scripts/dusky_tui. A schema module (ENGINE_TYPE, TARGET_FILE, SCHEMA)
# is rendered by dusky_tui/python/main/main.py, which imports the framework as
# the top-level `python` package and searches ~/user_scripts for schemas.
{
  pkgs,
  dusky,
}: let
  upstream = "${dusky}/user_scripts";

  # Copy the framework into the store and teach main.py to also find schemas
  # under the store user_scripts (the Arch model assumes ~/user_scripts).
  duskyTui = pkgs.stdenv.mkDerivation {
    name = "dusky-tui-framework";
    src = "${upstream}/dusky_tui";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      substituteInPlace $out/python/main/main.py \
        --replace 'Path("~/user_scripts").expanduser().resolve(),' \
                  'Path("~/user_scripts").expanduser().resolve(), Path("${upstream}").resolve(),'
    '';
  };

  pyTui = pkgs.python3.withPackages (ps: with ps; [textual rich]);
in {
  inherit duskyTui pyTui;

  # A binary that opens one schema: `mkTui "dusky-power" "power/tui_power.py" [...]`.
  # `runtimeInputs` are the commands the schema's engine shells out to.
  mkTui = name: schema: runtimeInputs:
    pkgs.writeShellApplication {
      checkPhase = "";
      inherit name;
      runtimeInputs = [pyTui] ++ runtimeInputs;
      text = ''
        export PYTHONPATH="${duskyTui}''${PYTHONPATH:+:$PYTHONPATH}"
        exec ${pyTui}/bin/python3 ${duskyTui}/python/main/main.py \
          ${upstream}/${schema} "$@"
      '';
    };
}
