{ config, pkgs, lib, dusky, ... }:

let
  matugenSrc = "${dusky}/.config/matugen";

  # Merge upstream templates with our overrides (ours win on conflict)
  mergedTemplates = pkgs.runCommand "matugen-templates-merged" {} ''
    mkdir -p $out
    cp -a ${matugenSrc}/templates/* $out/
    # Override with dusky-nix vibrant variants
    cp -f ${../../assets/templates/btop.theme} $out/btop.theme
    cp -f ${../../assets/templates/omp-theme.omp.json} $out/omp-theme.omp.json
  '';
in
{
  # Deploy matugen config.toml with patched post_hooks
  # Post hooks use packaged script names on $PATH instead of ~/user_scripts/...
  xdg.configFile."matugen/config.toml".source = ./matugen-config.toml;

  # Deploy merged templates (upstream + dusky-nix overrides)
  xdg.configFile."matugen/templates" = {
    source = mergedTemplates;
    recursive = true;
  };

  # Deploy all presets
  xdg.configFile."matugen/presets" = {
    source = "${matugenSrc}/presets";
    recursive = true;
  };

  home.packages = [ pkgs.matugen pkgs.oh-my-posh ];

  # Oh My Posh — use matugen-generated theme, fallback to built-in
  programs.zsh.initContent = lib.mkBefore ''
    _omp_theme="$HOME/.config/matugen/generated/omp-theme.omp.json"
    if [[ ! -f "$_omp_theme" ]]; then
      _omp_theme="${pkgs.oh-my-posh}/share/oh-my-posh/themes/1_shell.omp.json"
    fi
    eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config "$_omp_theme")"
    unset _omp_theme
  '';

  # Deploy default wallpaper from upstream dusky
  home.activation.deployWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Pictures/wallpapers"
    if [ ! -f "$HOME/Pictures/wallpapers/dusk_default.jpg" ]; then
      run cp "${dusky}/Pictures/wallpapers/dusk_default.jpg" "$HOME/Pictures/wallpapers/"
    fi
  '';

  # Generate default matugen colors on first activation if none exist
  home.activation.createMatugenGenerated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/matugen/generated"
    if [ ! -f "$HOME/.config/matugen/generated/rofi-colors.rasi" ]; then
      run ${pkgs.matugen}/bin/matugen \
        -c "$HOME/.config/matugen/config.toml" \
        --mode dark \
        image "${dusky}/Pictures/wallpapers/dusk_default.jpg" || true
    fi
  '';
}
