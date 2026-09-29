# profiles/home/zen-transparency.nix — Transparent Zen mod (sameerasw, theme-store UUID
# 642854b5-88b4-4c40-b256-e035532109df) settings as a one-time seed for Zen.
#
# Writes the mod's prefs into the default profile's prefs.js ONCE, then leaves them alone so
# live UI tweaks in the browser persist (unlike user.js, which would re-assert every launch).
# Profile-agnostic: discovers the default profile from ~/.zen/profiles.ini, so it works on any
# host regardless of Zen's randomly-generated profile dir name. Marker-gated → runs once; skips
# if Zen is open (never races a live prefs.js). No-op if Zen was never launched (no profile yet).
#
# ponytail: prefs only. The .xpi extensions (Zen Internet, Dark Reader, MetaMask, Bitwarden,
# uBlock) and their runtime data stay in-profile — declaring those means the flake module owning
# the whole profile, not worth risking a wallet for. Re-seed by deleting the marker with Zen closed.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dusky-desktop.zenTransparency;
in {
  options.dusky-desktop.zenTransparency.enable =
    lib.mkEnableOption "seed the Transparent Zen mod prefs into the default Zen profile (one-time)";

  config = lib.mkIf cfg.enable {
    home.activation.seedZenTransparency = lib.hm.dag.entryAfter ["writeBoundary"] ''
            ini="$HOME/.zen/profiles.ini"
            if [ -f "$ini" ]; then
              # Default profile's relative Path from profiles.ini (falls back to the first profile).
              rel=$(${pkgs.gawk}/bin/awk -F= '
                /^\[/{ inp = ($0 ~ /^\[Profile/); p="" }
                inp && $1=="Path"{ p=$2 }
                inp && $1=="Default" && $2=="1" && p!=""{ print p; exit }
              ' "$ini")
              if [ -z "$rel" ]; then
                rel=$(${pkgs.gawk}/bin/awk -F= '/^\[/{inp=($0~/^\[Profile/)} inp&&$1=="Path"{print $2; exit}' "$ini")
              fi
              if [ -n "$rel" ]; then
                profile="$HOME/.zen/$rel"
                marker="$profile/.hm-transparent-zen-seeded"
                if [ -d "$profile" ] && [ ! -e "$marker" ]; then
                  if ${pkgs.procps}/bin/pgrep -f zen-beta >/dev/null 2>&1; then
                    echo "zen-transparency seed: Zen is running, skipping (seeds next switch when closed)"
                  else
                    $DRY_RUN_CMD tee -a "$profile/prefs.js" >/dev/null <<'PREFS'
      user_pref("browser.tabs.allow_transparent_browser", true);
      user_pref("zen.widget.linux.transparency", true);
      user_pref("zen.view.grey-out-inactive-windows", false);
      user_pref("mod.sameerasw.zen_bg_blur", "3px");
      user_pref("mod.sameerasw.zen_bg_color_enabled", false);
      user_pref("mod.sameerasw.zen_bg_img", "url('https://github.com/sameerasw/my-internet/blob/main/wallpapers/zen-coral-01.jpeg?raw=true')");
      user_pref("mod.sameerasw.zen_bg_img_enabled", false);
      user_pref("mod.sameerasw.zen_bg_img_not_fullscreen", false);
      user_pref("mod.sameerasw.zen_bg_opacity", "0.8");
      user_pref("mod.sameerasw.zen_compact_sidebar_width", "165px");
      user_pref("mod.sameerasw.zen_no_shadow", false);
      user_pref("mod.sameerasw.zen_notab_img", "url('https://github.com/sameerasw/my-internet/blob/main/wave-light.png?raw=true')");
      user_pref("mod.sameerasw.zen_notab_img_opacity", "1");
      user_pref("mod.sameerasw.zen_notab_img_size", "150px");
      user_pref("mod.sameerasw.zen_tab_switch_anim", true);
      user_pref("mod.sameerasw.zen_trackpad_anim", false);
      user_pref("mod.sameerasw.zen_transparency_color", "#00000000");
      user_pref("mod.sameerasw.zen_transparent_glance_enabled", false);
      user_pref("mod.sameerasw.zen_transparent_sidebar_enabled", true);
      user_pref("mod.sameerasw.zen_urlbar_zoom_anim", false);
      user_pref("mod.sameerasw_zen_animations", "1");
      user_pref("mod.sameerasw_zen_compact_sidebar_type", "0");
      user_pref("mod.sameerasw_zen_empty_tab_logo", "0");
      user_pref("mod.sameerasw_zen_light_tint", "2");
      PREFS
                    $DRY_RUN_CMD touch "$marker"
                    echo "zen-transparency seed: wrote Transparent Zen prefs into $profile/prefs.js (one-time)"
                  fi
                fi
              fi
            fi
    '';
  };
}
