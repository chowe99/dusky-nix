# hosts/will/configuration.nix — Will's machine: the dusky desktop.
# Hardware is unknown until install; see ./INSTALL.md.
{lib, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/nixos/standalone.nix
  ];

  # ── Change these for Will ────────────────────────────────────────────────
  time.timeZone = "Australia/Perth";
  i18n.defaultLocale = "en_AU.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS"
    "LC_IDENTIFICATION"
    "LC_MEASUREMENT"
    "LC_MONETARY"
    "LC_NAME"
    "LC_NUMERIC"
    "LC_PAPER"
    "LC_TELEPHONE"
    "LC_TIME"
  ] (_: "en_AU.UTF-8");
  # console.keyMap = "us";

  # ── Login ────────────────────────────────────────────────────────────────
  # tuigreet asks for Will's password after the LUKS prompt (no autologin).
  # No password is set here: INSTALL.md sets it with `nixos-enter … passwd`
  # to the same passphrase as the disk. Until then the account is locked
  # (never a known default password). Groups: wheel networkmanager video audio
  # (profiles/nixos/standalone.nix).

  # First install's NixOS release. Never change after install.
  system.stateVersion = "26.05";
}
