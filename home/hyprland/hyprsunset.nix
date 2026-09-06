{
  config,
  pkgs,
  lib,
  ...
}: {
  # Deploy hyprsunset.conf
  #
  # hyprsunset applies its temperature as a CTM at scanout, across the whole
  # output. A warm daytime profile is therefore not a subtle tint — it crushes
  # blue in everything, and while flat desktop greys hide it (the eye adapts),
  # games and video read as washed out and desaturated. So the day profile
  # stays at 6500K (hyprsunset's neutral, i.e. filter off) and the warming
  # only starts as the sun goes down.
  xdg.configFile."hypr/hyprsunset.conf".text = ''
    # Daytime - filter off (6500K is neutral)
    profile {
        time = 05:00
        temperature = 6500
    }

    # 5 PM - first gentle step down
    profile {
        time = 17:00
        temperature = 5000
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
