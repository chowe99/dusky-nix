{ config, pkgs, lib, ... }:

let
  vaultDir = ../../assets/obsidian-vault;
in
{
  # Obsidian vault configuration (pensive vault)
  # Only the .obsidian settings are managed — vault content is user-owned
  xdg.configFile = {
    "obsidian-vault/appearance.json" = {
      target = "../Documents/pensive/.obsidian/appearance.json";
      source = "${vaultDir}/appearance.json";
    };
    "obsidian-vault/hotkeys.json" = {
      target = "../Documents/pensive/.obsidian/hotkeys.json";
      source = "${vaultDir}/hotkeys.json";
    };
    "obsidian-vault/snippets/header_hide.css" = {
      target = "../Documents/pensive/.obsidian/snippets/header_hide.css";
      source = "${vaultDir}/snippets/header_hide.css";
    };
  };

  # Create matugen theme symlink for Obsidian
  home.activation.obsidianMatugenTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SNIPPET_DIR="$HOME/Documents/pensive/.obsidian/snippets"
    mkdir -p "$SNIPPET_DIR"
    LINK="$SNIPPET_DIR/matugen-theme.css"
    TARGET="$HOME/.config/matugen/generated/obsidian-theme.css"
    if [ ! -L "$LINK" ] || [ "$(readlink "$LINK")" != "$TARGET" ]; then
      ln -sf "$TARGET" "$LINK"
    fi
  '';
}
