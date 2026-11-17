{
  pkgs,
  dusky,
}:
# Upstream's Rust apps (user_scripts/dusky/<name>): Iced/wgpu on Wayland. They
# share ../../rust_shared (a patched fontdb + ui_fonts.rs), so the source is the
# whole user_scripts tree and cargo runs in the app's subdir.
let
  inherit (pkgs) lib;
  src = "${dusky}/user_scripts";
  # winit/wgpu dlopen these at runtime; they are not in DT_NEEDED.
  runtimeLibs = with pkgs; [wayland libxkbcommon vulkan-loader libGL];
  # Upstream targets Arch and hard-codes FHS paths. Map them to NixOS: GPU
  # driver manifests live under /run/opengl-driver, setuid sudo in wrappers.
  fhs = {
    "/usr/bin/sudo" = "/run/wrappers/bin/sudo";
    "/usr/bin/bash" = "${pkgs.bash}/bin/bash";
    "/usr/bin/systemd-run" = "${pkgs.systemd}/bin/systemd-run";
    "/usr/bin/rfkill" = "${pkgs.util-linux}/bin/rfkill";
    "/usr/bin/powertop" = "${pkgs.powertop}/bin/powertop";
    "/usr/bin/echo" = "${pkgs.coreutils}/bin/echo";
    "/usr/bin/sleep" = "${pkgs.coreutils}/bin/sleep";
    "/usr/bin/true" = "${pkgs.coreutils}/bin/true";
    "/usr/share/vulkan/icd.d" = "/run/opengl-driver/share/vulkan/icd.d";
    "/usr/share/glvnd/egl_vendor.d" = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    # Packaged-defaults fallbacks → this package's own share/.
    "/usr/share/dusky_tray" = "@out@/share/dusky_tray";
    "/usr/share/dusky_center" = "@out@/share/dusky_center";
  };
  sedFhs = lib.concatStringsSep " " (lib.mapAttrsToList (from: to: "-e 's|${from}|${to}|g'") fhs);
in
  name: args:
    pkgs.rustPlatform.buildRustPackage ({
        pname = name;
        version = (lib.importTOML "${src}/dusky/${name}/Cargo.toml").package.version;
        inherit src;
        cargoRoot = "dusky/${name}";
        buildAndTestSubdir = "dusky/${name}";
        cargoLock.lockFile = "${src}/dusky/${name}/Cargo.lock";
        nativeBuildInputs = with pkgs; [pkg-config wayland-scanner];
        buildInputs = runtimeLibs;
        # Upstream's tests spawn real processes, need a GPU and a session.
        doCheck = false;
        postPatch =
          ''
            # pins target-dir to /tmp, outside the sandbox
            rm -f dusky/${name}/.cargo/config.toml
            { grep -rlZ -e /usr/bin/ -e /usr/share/ dusky/${name}/src || true; } | xargs -0r sed -i ${sedFhs}
            { grep -rlZ @out@ dusky/${name}/src || true; } | xargs -0r sed -i "s|@out@|$out|g"
            # The shared fontdb loads 7 fixed Arch font files and nothing else;
            # missing ones mean no text at all (icons still draw).
            substituteInPlace rust_shared/fontdb/src/dusky.rs \
              --replace-fail /usr/share/fonts/OTF/ ${pkgs.atkinson-hyperlegible}/share/fonts/opentype/ \
              --replace-fail /usr/share/fonts/TTF/DejaVu ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVu
          ''
          + args.postPatch or "";
        postFixup = ''
          patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} $out/bin/${name}
        '';
      }
      // removeAttrs args ["postPatch"])
