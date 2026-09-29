{
  config,
  pkgs,
  lib,
  ...
}: {
  # The families the configs below and upstream's themes name: fontconfig
  # aliases (Atkinson Hyperlegible Next, JetBrainsMono Nerd Font), GTK
  # (Adwaita Sans), waybar/rofi/kitty (JetBrainsMono Nerd Font), hyprlock's
  # matugen template (Rubik, Material Symbols Rounded), rofi emoji picker.
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    atkinson-hyperlegible-next
    nerd-fonts.jetbrains-mono
    adwaita-fonts
    rubik
    material-symbols
    noto-fonts-color-emoji
  ];

  # Deploy fontconfig
  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <alias>
        <family>serif</family>
        <prefer>
          <family>Atkinson Hyperlegible Next</family>
        </prefer>
      </alias>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>Atkinson Hyperlegible Next</family>
        </prefer>
      </alias>
      <alias>
        <family>sans</family>
        <prefer>
          <family>Atkinson Hyperlegible Next</family>
        </prefer>
      </alias>
      <alias>
        <family>monospace</family>
        <prefer>
          <family>JetBrainsMono Nerd Font Mono</family>
        </prefer>
      </alias>

      <match target="pattern">
        <test qual="any" name="family"><string>Arial</string></test>
        <edit name="family" mode="assign" binding="strong">
          <string>Atkinson Hyperlegible Next</string>
        </edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Helvetica</string></test>
        <edit name="family" mode="assign" binding="strong">
          <string>Atkinson Hyperlegible Next</string>
        </edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Verdana</string></test>
        <edit name="family" mode="assign" binding="strong">
          <string>Atkinson Hyperlegible Next</string>
        </edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Times New Roman</string></test>
        <edit name="family" mode="assign" binding="strong">
          <string>Atkinson Hyperlegible Next</string>
        </edit>
      </match>

      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
      </match>
    </fontconfig>
  '';
}
