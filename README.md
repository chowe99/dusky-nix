# dusky-nix

A Nix port of the [dusky](https://github.com/dusklinux/dusky) Hyprland
dotfiles, plus a desktop profile layer that turns it into a complete NixOS
machine: greetd → UWSM → Hyprland, waybar with matugen theming, rofi menus,
mako, hyprlock, kitty + zsh (fzf-tab, vi-mode, oh-my-posh), Zen browser,
Plymouth, Snapper snapshots and the CachyOS kernel from its binary cache.

Upstream's dotfiles are a non-flake input (`dusky-dotfiles`); configs are
deployed from it verbatim wherever possible and every script it ships is
packaged with its own runtime dependencies (`nix build .#checks.x86_64-linux.runtime-deps`
audits that).

## Layout

| Path | What |
|---|---|
| `packages/` | Upstream's `user_scripts` as Nix packages (`dusky-scripts-all`) |
| `modules/`, `options/` | The plain port, NixOS side (`nixosModules.{base,desktop,audio,networking,services,laptop,gpu,virtualization,options}`) |
| `home/` | The plain port, home-manager side (`homeManagerModules.{hyprland,theming,waybar,apps,…}`) |
| `profiles/nixos/` | Desktop profile, NixOS side (`nixosModules.{standalone,common,desktop-base,cachyos-kernel,disk-snapshot}`) |
| `profiles/home/` | Desktop profile, home side (`homeManagerModules.{standalone,common,zsh,kitty,tmux,fastfetch,dusky-extras,opencode,…}`) |
| `hosts/default` | `nixosConfigurations.default`: upstream's own machine, plain port only |
| `hosts/will` | `nixosConfigurations.will`: a complete desktop on unknown hardware ([INSTALL.md](hosts/will/INSTALL.md)) |
| `template/` | `templates.default`: a flake with one host and one user |
| `checks/` | `nix flake check`: the runtime-dependency audit |

## Use it

```sh
nix flake init -t github:chowe99/dusky-nix
```

gives a flake with one host and one user built by `lib.mkSystem`. Or import
the pieces into your own config:

| Output | What |
|---|---|
| `nixosModules.standalone` | A complete machine: `common` + `desktop-base` + `cachyos-kernel`, nix/boot/firmware/NetworkManager basics, the user (zsh, wheel). No sshd. |
| `nixosModules.common` | Desktop core: greetd (tuigreet, or `dusky-desktop.autoLogin`), Plymouth, Snapper on `/` + `/home`, nightly `dua` snapshot. |
| `nixosModules.desktop-base` | PipeWire, Bluetooth, polkit, udisks/udiskie, LocalSend, gpu-screen-recorder, fonts. Opt-in `desktop-base.{kdeconnect,mosh}`. |
| `nixosModules.cachyos-kernel` | `cachyos-kernel.enable` + the prebuilt-kernel cache. |
| `homeManagerModules.standalone` | A complete user: `common` + kitty, zsh, fzf, zoxide, fd, ripgrep, fastfetch, tmux, keybindings; Zen, Thunar, btop. |
| `homeManagerModules.common` | Desktop core: patched waybar themes, autostart, mako/battery unit fixes, matugen + wallpaper bootstrap, dusky-extras menu, Zen transparency. |
| `homeManagerModules.*` | The individual pieces (`zsh` has `dusky-desktop.zsh.<slot>` hooks for your own init lines), plus `opencode`. |
| `lib.duskyModules { apps ? … }` | The port's NixOS + home-manager module stack; `lib.standaloneApps` is a trimmed app list. |
| `lib.mkSystem` | `nixosSystem` with home-manager, the dusky stack and the CachyOS/opencode overlays. |
| `overlays.{default,cachyos,opencode}` | `pkgs.dusky.*`; CachyOS kernels; a known-good opencode build (temporary pin). |

`homeManagerModules.standalone` expects the `inputs` special arg to contain
`zen-browser` (`lib.mkSystem` passes this flake's).
