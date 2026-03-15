{ pkgs, dusky }:

let
  # Upstream dusky scripts (unpatched — pulled via flake input)
  upstream = "${dusky}/user_scripts";

  # Patched scripts (modified from upstream for NixOS compatibility)
  patched = ../../assets/scripts;
in
pkgs.symlinkJoin {
  name = "dusky-misc-scripts";
  paths = [
    # --- Hyprlock ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-lock";
      runtimeInputs = with pkgs; [ hyprlock procps ];
      text = builtins.readFile "${upstream}/hyprlock/lock.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-hyprlock-switcher";
      runtimeInputs = with pkgs; [ rofi coreutils ];
      text = builtins.readFile "${upstream}/hyprlock/dusky_hyprlock_switcher.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-hyprlock-battery";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${upstream}/hyprlock/battery_status.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-hyprlock-capslock";
      runtimeInputs = with pkgs; [ hyprland jq ];
      text = builtins.readFile "${upstream}/hyprlock/check_capslock.sh";
    })

    # --- Wlogout / SwayOSD ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wlogout-scale";
      runtimeInputs = with pkgs; [ wlogout hyprland jq ];
      text = builtins.readFile "${upstream}/wlogout/wlogout_scale.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-restart-swayosd";
      runtimeInputs = with pkgs; [ swayosd procps ];
      text = builtins.readFile "${upstream}/swayosd/restart_swayosd.sh";
    })

    # --- Power / Performance ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-power";
      runtimeInputs = with pkgs; [ gum ];
      text = builtins.readFile "${upstream}/power/dusky_power.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-process-terminator";
      runtimeInputs = with pkgs; [ gum procps systemd ];
      text = builtins.readFile "${upstream}/performance/services_and_process_terminator.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-sysbench";
      runtimeInputs = with pkgs; [ sysbench util-linux coreutils gawk procps ];
      text = builtins.readFile "${upstream}/performance/sysbench_benchmark.sh";
    })

    # --- Hypridle ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-hypridle";
      runtimeInputs = with pkgs; [ hypridle coreutils ];
      text = builtins.readFile "${upstream}/hypridle/dusky_hypridle.sh";
    })

    # --- Services ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-service-toggle";
      runtimeInputs = with pkgs; [ systemd coreutils ];
      text = builtins.readFile "${upstream}/services/dusky_service_toggle.sh";
    })

    # --- Media ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-google-image-search";
      runtimeInputs = with pkgs; [ grim slurp wl-clipboard curl xdg-utils ];
      text = builtins.readFile "${upstream}/google_image_search/google_image_search.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-music-recognition";
      runtimeInputs = with pkgs; [ ffmpeg libnotify jq pulseaudio songrec ];
      text = builtins.readFile "${upstream}/music/music_recognition.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-spotify-toggle";
      runtimeInputs = with pkgs; [ hyprland procps ];
      text = builtins.readFile "${upstream}/spotify/spotify_toggle.sh";
    })

    # --- LLM ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-ollama-terminal";
      runtimeInputs = with pkgs; [ curl jq wl-clipboard coreutils ];
      text = builtins.readFile "${upstream}/llm/ollama_terminal.sh";
    })

    # --- ASUS ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-asus-control";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${upstream}/asus/asusctl.sh";
    })

    # --- Reload helpers (PATCHED — use packaged app names instead of hardcoded paths) ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-cc-restart";
      runtimeInputs = with pkgs; [ procps systemd coreutils ];
      text = builtins.readFile "${patched}/control_center/cc_restart.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-reload-sliders";
      runtimeInputs = with pkgs; [ procps systemd coreutils ];
      text = builtins.readFile "${patched}/sliders/reload_sliders.sh";
    })

    # --- Wayclick ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wayclick";
      runtimeInputs = with pkgs; [ pulseaudio coreutils libinput ];
      text = builtins.readFile "${upstream}/wayclick/dusky_wayclick.sh";
    })

    # --- TTS/STT (Python wrappers — require user venv with ML deps) ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-kokoro-tts";
      runtimeInputs = with pkgs; [ python3 ];
      text = ''exec python3 ${upstream}/tts_stt/dusky_kokoro/dusky_main.py "$@"'';
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-parakeet-stt";
      runtimeInputs = with pkgs; [ python3 ];
      text = ''exec python3 ${upstream}/tts_stt/dusky_parakeet/dusky_stt_main.py "$@"'';
    })
  ];
}
