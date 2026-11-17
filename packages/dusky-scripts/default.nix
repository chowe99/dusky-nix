{
  pkgs,
  dusky,
}: let
  # Upstream dusky now targets Python 3.15 (lazy imports, comprehension
  # unpacking, builtin frozendict, `version_info < (3, 15)` gates), so the
  # script packages see python315 as `python3`. Shallow on purpose: only their
  # own pkgs.python3 references change, not other packages' build inputs.
  # pkgsPy314 is for local ML daemons whose deps (onnxruntime) 3.15 lacks in cache.
  pkgsPy314 = pkgs;
  # 3.15 packages aren't in cache.nixos.org, so they build from source, and
  # many test suites still assert 3.14 behaviour (error wording, syntax that
  # 3.15 now accepts). Skip checks: also drops the test-only dependency tree.
  py = pkgs.python315.override {
    self = py;
    packageOverrides = _: super:
      builtins.mapAttrs (_: p:
        if p ? overridePythonAttrs
        then p.overridePythonAttrs {doCheck = false;}
        else p)
      super
      // {
        # its import check loads the trio backend, whose dep was test-only
        jeepney = super.jeepney.overridePythonAttrs {
          doCheck = false;
          pythonImportsCheck = ["jeepney"];
        };
      };
  };
  pkgs' = pkgs // {python3 = py; python3Packages = py.pkgs;};
in let
  pkgs = pkgs';
in {
  dusky-hypr-scripts = import ./hypr-scripts.nix {inherit pkgs dusky;};
  dusky-theme-scripts = import ./theme-scripts.nix {inherit pkgs dusky;};
  dusky-waybar-scripts = import ./waybar-scripts.nix {inherit pkgs dusky;};
  dusky-rofi-scripts = import ./rofi-scripts.nix {inherit pkgs dusky;};
  dusky-audio-scripts = import ./audio-scripts.nix {inherit pkgs dusky;};
  dusky-battery-scripts = import ./battery-scripts.nix {inherit pkgs dusky;};
  dusky-drive-scripts = import ./drive-scripts.nix {inherit pkgs dusky;};
  dusky-screenshot-scripts = import ./screenshot-scripts.nix {inherit pkgs dusky;};
  dusky-rust-apps = import ./rust-apps.nix {inherit pkgs dusky;};
  dusky-control-center = import ./control-center.nix {inherit pkgs dusky;};
  dusky-network-scripts = import ./network-scripts.nix {inherit pkgs dusky;};
  dusky-mako-scripts = import ./mako-scripts.nix {inherit pkgs dusky;};
  dusky-misc-scripts = import ./misc-scripts.nix {inherit pkgs dusky pkgsPy314;};
  dusky-tui-scripts = import ./tui-scripts.nix {inherit pkgs dusky;};
}
