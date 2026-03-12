{ config, pkgs, lib, ... }:

{
  # Deploy hyprsunset.conf
  xdg.configFile."hypr/hyprsunset.conf".text = ''
    # Morning - gently warm, like early daylight
    profile {
        time = 05:00
        temperature = 4000
    }

    # 5 PM - coolest / neutral point
    profile {
        time = 17:00
        temperature = 3500
    }

    # 7 PM - starting to warm up
    profile {
        time = 19:00
        temperature = 3000
    }

    # 10 PM - strong evening warmth
    profile {
        time = 22:00
        temperature = 2000
    }
  '';
}
