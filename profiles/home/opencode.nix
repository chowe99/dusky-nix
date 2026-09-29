# profiles/home/opencode.nix — opencode (terminal AI coding agent) with its
# default settings: no providers, MCP servers or permissions preset. Log in
# with your own provider via `opencode auth login`. pkgs.opencode is the
# known-good build from overlays.opencode when lib.mkSystem is used.
{lib, ...}: {
  programs.opencode = {
    enable = lib.mkDefault true;
    settings."$schema" = "https://opencode.ai/config.json";
  };
}
