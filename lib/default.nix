{ lib }:

{
  # Helper to create a desktop entry attrset for xdg.desktopEntries
  mkDesktopEntry = { name, exec, icon ? "", comment ? "", categories ? [], terminal ? false }:
    {
      inherit name exec icon comment categories terminal;
    };

  # Helper to create a writeShellApplication-style script package
  mkScript = { pkgs, name, runtimeInputs ? [], text }:
    pkgs.writeShellApplication {
      inherit name text;
      runtimeInputs = runtimeInputs;
    };

  # Helper to deploy a directory of config files via xdg.configFile
  mkConfigDir = { src, target }:
    lib.mapAttrs' (name: _:
      lib.nameValuePair "${target}/${name}" { source = "${src}/${name}"; }
    ) (builtins.readDir src);

  # Helper to conditionally include a module
  mkIfEnabled = condition: content:
    lib.mkIf condition content;
}
