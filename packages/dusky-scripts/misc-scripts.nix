{
  pkgs,
  dusky,
}: let
  # Upstream dusky scripts (unpatched — pulled via flake input)
  upstream = "${dusky}/user_scripts";

  # Patched scripts (modified from upstream for NixOS compatibility)
  patched = ../../assets/scripts;

  # Python packages for TTS/STT
  espeakng-loader = import ../python/espeakng-loader.nix {inherit pkgs;};
  phonemizer-fork = import ../python/phonemizer-fork.nix {inherit pkgs;};
  kokoro-onnx = import ../python/kokoro-onnx.nix {inherit pkgs espeakng-loader phonemizer-fork;};

  # Bundled Python environments for TTS/STT scripts
  tts-python = pkgs.python3.withPackages (_: [
    kokoro-onnx
    pkgs.python3Packages.numpy
    pkgs.python3Packages.onnxruntime
    pkgs.python3Packages.soundfile
  ]);
  stt-python = pkgs.python3.withPackages (ps: [
    ps.onnx-asr
    ps.numpy
    ps.onnxruntime
    ps.huggingface-hub
  ]);
  openwakeword = import ../python/openwakeword.nix {inherit pkgs;};
  voice-python = pkgs.python3.withPackages (ps: [
    openwakeword
    ps.onnx-asr
    ps.numpy
    ps.onnxruntime
    ps.huggingface-hub
    ps.sounddevice
    ps.scipy
    ps.scikit-learn
  ]);

  # Upstream's LLM side panel (llm/llm_side_panal): GTK3 app, config in
  # ~/.config/dusky/llm_side_panal/config.toml (created on first run).
  llmPanel = pkgs.stdenv.mkDerivation {
    pname = "dusky-llm-panel";
    version = "0";
    src = "${upstream}/llm/llm_side_panal";
    nativeBuildInputs = with pkgs; [makeWrapper wrapGAppsHook3 gobject-introspection];
    buildInputs = with pkgs; [gtk3 glib pango gdk-pixbuf];
    dontWrapGApps = true;
    installPhase = ''
      mkdir -p $out/bin $out/lib/dusky-llm-panel
      cp *.py config.toml $out/lib/dusky-llm-panel/
    '';
    postFixup = ''
      makeWrapper ${pkgs.python3.withPackages (ps: [ps.pygobject3 ps.pycairo])}/bin/python3 $out/bin/dusky-llm-panel \
        --add-flags "$out/lib/dusky-llm-panel/dusky_llm.py" \
        "''${gappsWrapperArgs[@]}" \
        --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.systemd]}
    '';
  };
in
  pkgs.symlinkJoin {
    name = "dusky-misc-scripts";
    paths = [
      # --- Hyprlock ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-lock";
        runtimeInputs = with pkgs; [hyprlock procps awww];
        text = builtins.readFile "${upstream}/hyprlock/lock.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-hyprlock-battery";
        runtimeInputs = with pkgs; [coreutils];
        text = builtins.readFile "${upstream}/hyprlock/battery_status.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-hyprlock-capslock";
        runtimeInputs = with pkgs; [hyprland jq];
        text = builtins.readFile "${upstream}/hyprlock/check_capslock.sh";
      })

      # --- Wlogout ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-wlogout-scale";
        runtimeInputs = with pkgs; [wlogout hyprland jq];
        text = builtins.readFile "${upstream}/wlogout/wlogout_scale.sh";
      })

      # --- Power / Performance ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-process-terminator";
        runtimeInputs = with pkgs; [gum procps systemd];
        text = builtins.readFile "${upstream}/performance/services_and_process_terminator.sh";
      })
      # Upstream rewrote sysbench_benchmark.sh in Python (stdlib only).
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-sysbench";
        runtimeInputs = with pkgs; [python3 sysbench util-linux];
        text = ''exec python3 ${upstream}/performance/sysbench_benchmark.py "$@"'';
      })

      # --- Hypridle ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-hypridle";
        runtimeInputs = with pkgs; [hypridle coreutils psmisc];
        text = builtins.readFile "${upstream}/hypridle/dusky_hypridle.sh";
      })

      # --- Services ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-service-toggle";
        runtimeInputs = with pkgs; [systemd coreutils];
        text = builtins.readFile "${upstream}/services/dusky_service_manager.sh";
      })

      # --- Media ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-google-image-search";
        runtimeInputs = with pkgs; [grim slurp wl-clipboard curl xdg-utils jq libnotify uwsm];
        text = builtins.readFile "${upstream}/google_image_search/google_image_search.sh";
      })
      # Upstream rewrote music_recognition.sh in Python: pw-record + songrec,
      # with a history browsed through fzf and rendered with rich.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-music-recognition";
        runtimeInputs = with pkgs; [(python3.withPackages (ps: [ps.rich])) pipewire songrec fzf libnotify wl-clipboard xdg-utils];
        text = ''exec python3 ${upstream}/music/music_recognition.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-spotify-toggle";
        runtimeInputs = with pkgs; [hyprland procps];
        text = builtins.readFile "${upstream}/spotify/spotify_toggle.sh";
      })

      # --- LLM ---
      # Upstream replaced ollama_terminal.sh with llm_side_panal, a GTK3
      # side panel talking to Ollama (services.ollama). See llmPanel above.
      llmPanel
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-llm-toggle";
        runtimeInputs = [pkgs.glib llmPanel];
        # toggle_llm_side_panal.sh: raise the running instance over D-Bus, else
        # start one (upstream's resolves dusky_llm.py next to itself).
        text = ''
          gdbus call --session --dest org.dusky.llm --object-path /org/dusky/llm \
            --method org.freedesktop.Application.Activate "{}" >/dev/null 2>&1 && exit 0
          exec dusky-llm-panel "$@"
        '';
      })

      # --- ASUS ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-asus-control";
        runtimeInputs = with pkgs; [coreutils];
        text = builtins.readFile "${upstream}/asus/asusctl.sh";
      })

      # --- Reload helpers (PATCHED — use packaged app names instead of hardcoded paths) ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-cc-restart";
        runtimeInputs = with pkgs; [procps systemd coreutils];
        text = builtins.readFile "${patched}/control_center/cc_restart.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-reload-sliders";
        runtimeInputs = with pkgs; [procps util-linux coreutils uwsm];
        text = builtins.readFile "${patched}/sliders/reload_sliders.sh";
      })

      # --- Wallpaper Download ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-wallpaper-download";
        runtimeInputs = with pkgs; [curl unzip coreutils];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/150_wallpapers_download.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-walls-download";
        runtimeInputs = with pkgs; [curl jq gum coreutils findutils];
        text = builtins.readFile "${patched}/walls/dusky_walls_download.sh";
      })

      # --- Portable Arch Setup Scripts (work on NixOS without modification) ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-mouse-reverse";
        runtimeInputs = with pkgs; [gawk hyprland procps];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/265_mouse_button_reverse.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-file-manager-switch";
        runtimeInputs = with pkgs; [gawk xdg-utils coreutils hyprland];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/235_file_manager_switch.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-browser-switch";
        runtimeInputs = with pkgs; [gawk xdg-utils coreutils hyprland];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/236_browser_switcher.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-editor-switch";
        runtimeInputs = with pkgs; [gawk xdg-utils coreutils hyprland];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/237_text_editer_switcher.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-terminal-switch";
        runtimeInputs = with pkgs; [gawk coreutils hyprland];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/238_terminal_switcher.sh";
      })
      # dusky-waypaper-reset removed: upstream dropped waypaper (replaced by awww),
      # so 170_waypaper_config_reset.sh no longer exists.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-animation-default";
        runtimeInputs = with pkgs; [coreutils hyprland];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/006_animation_default.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-cursor-bibata";
        runtimeInputs = with pkgs; [curl gnutar hyprland ncurses];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/375_cursor_theme_bibata_classic_modern.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-clipboard-switch";
        runtimeInputs = with pkgs; [hyprland util-linux coreutils];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/460_switch_clipboard.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-hosts-blocker";
        runtimeInputs = with pkgs; [gawk coreutils];
        text = builtins.readFile "${upstream}/arch_setup_scripts/scripts/325_hosts_files_block.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-blur-visibility";
        runtimeInputs = with pkgs; [brightnessctl];
        text = builtins.readFile "${patched}/arch_portable/155_blur_shadow_opacity.sh";
      })

      # --- Neovim ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-neovim-manager";
        runtimeInputs = with pkgs; [neovim git coreutils];
        text = builtins.readFile "${upstream}/nvim/dusky_neovim_manager.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-reset-neovim";
        runtimeInputs = with pkgs; [coreutils];
        text = builtins.readFile "${upstream}/nvim/reset/01_reset_neovim.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-neovim-plugins";
        runtimeInputs = with pkgs; [neovim git iputils coreutils];
        text = builtins.readFile "${upstream}/nvim/reset/02_cli_plugins_download.sh";
      })

      # --- GTK ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-gsettings";
        runtimeInputs = with pkgs; [glib coreutils hyprland xrdb];
        text = builtins.readFile "${upstream}/gtk/dusky_gsettings.sh";
      })

      # --- Portable Arch Setup Scripts (additional) ---

      # --- Wayclick ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-wayclick";
        runtimeInputs = with pkgs; [pulseaudio coreutils libinput libnotify uv];
        text = builtins.readFile "${upstream}/wayclick/dusky_wayclick.sh";
      })

      # --- TTS voice picker (rofi menu) ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-kokoro-voice";
        runtimeInputs = with pkgs; [rofi libnotify coreutils];
        text = ''
                  FIFO_PATH="/tmp/dusky_kokoro.fifo"
                  VOICE_FILE="/tmp/dusky_kokoro.voice"
                  VOICE_LIST_FILE="/tmp/dusky_kokoro.voices"
                  FALLBACK_VOICES="af_sarah
          af_bella
          af_nicole
          af_sky
          am_adam
          am_michael
          bf_emma
          bf_isabella
          bm_george
          bm_lewis"
                  # Use daemon-generated voice list if available, else fallback
                  if [[ -f "$VOICE_LIST_FILE" ]]; then
                    VOICES=$(cat "$VOICE_LIST_FILE")
                  else
                    VOICES="$FALLBACK_VOICES"
                  fi
                  CURRENT=$(cat "$VOICE_FILE" 2>/dev/null || echo "af_sarah")
                  CHOICE=$(echo "$VOICES" | rofi -dmenu -p "TTS Voice" -mesg "Current: $CURRENT" -theme-str 'window {width: 300px;}')
                  if [[ -n "$CHOICE" ]]; then
                    printf '!voice %s\n' "$CHOICE" > "$FIFO_PATH"
                  fi
        '';
      })

      # --- TTS/STT daemon launchers (started by systemd or manually) ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-kokoro-tts-daemon";
        runtimeInputs = [tts-python pkgs.mpv pkgs.libnotify pkgs.piper-tts];
        text = ''exec ${tts-python}/bin/python3 ${patched}/tts_stt/kokoro/dusky_main.py --daemon "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-parakeet-stt-daemon";
        runtimeInputs = [stt-python pkgs.wl-clipboard pkgs.libnotify];
        text = ''exec ${stt-python}/bin/python3 ${patched}/tts_stt/parakeet/dusky_stt_main.py --daemon "$@"'';
      })

      # --- TTS trigger (keybind target): ensure daemon running, pipe clipboard to FIFO ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-kokoro-tts";
        runtimeInputs = with pkgs; [wl-clipboard libnotify coreutils];
        text = ''
          PID_FILE="/tmp/dusky_kokoro.pid"
          READY_FILE="/tmp/dusky_kokoro.ready"
          FIFO_PATH="/tmp/dusky_kokoro.fifo"

          is_running() {
            [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
          }

          case "''${1:-}" in
            --kill)
              if is_running; then
                kill "$(cat "$PID_FILE")" 2>/dev/null || true
                echo "Daemon stopped."
              fi
              rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
              exit 0 ;;
            --status)
              if is_running; then echo "Running (PID: $(cat "$PID_FILE"))"; else echo "Not running"; fi
              exit 0 ;;
            --restart)
              is_running && kill "$(cat "$PID_FILE")" 2>/dev/null || true
              rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
              systemctl --user restart dusky-kokoro-tts.service 2>/dev/null || dusky-kokoro-tts-daemon &
              exit 0 ;;
          esac

          # Start daemon if not running
          if ! is_running; then
            rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
            systemctl --user start dusky-kokoro-tts.service 2>/dev/null || dusky-kokoro-tts-daemon &
            # Wait for ready (30s timeout)
            for _ in $(seq 1 300); do
              [[ -f "$READY_FILE" ]] && break
              sleep 0.1
            done
            if [[ ! -f "$READY_FILE" ]]; then
              notify-send -a "Kokoro TTS" -u critical "Startup Failed" "Daemon not ready after 30s"
              exit 1
            fi
          fi

          # Grab clipboard and send to FIFO
          INPUT_TEXT=$(timeout 2 wl-paste 2>/dev/null || true)
          if [[ -z "$INPUT_TEXT" ]]; then
            notify-send -a "Kokoro TTS" -t 2000 "Clipboard Empty" "Select text first"
            exit 0
          fi

          CLEAN_TEXT=$(printf '%s' "$INPUT_TEXT" | tr '\n' ' ')
          printf '%s\n' "$CLEAN_TEXT" > "$FIFO_PATH" &
          WRITE_PID=$!

          # Wait up to 2s for FIFO write
          WRITE_OK=false
          for _ in $(seq 1 20); do
            if ! kill -0 "$WRITE_PID" 2>/dev/null; then
              wait "$WRITE_PID" 2>/dev/null && WRITE_OK=true
              break
            fi
            sleep 0.1
          done

          if $WRITE_OK; then
            notify-send -a "Kokoro TTS" -t 1000 "Processing..."
          else
            kill "$WRITE_PID" 2>/dev/null || true
            notify-send -a "Kokoro TTS" -u critical "Error" "Daemon unresponsive"
          fi
        '';
      })

      # --- Voice Assistant daemon launcher ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-voice-assistant-daemon";
        runtimeInputs = [voice-python pkgs.pipewire pkgs.mpv pkgs.libnotify pkgs.sox pkgs.procps pkgs.kitty pkgs.wireplumber pkgs.coreutils];
        # OpenRouter key: $OPENROUTER_API_KEY, else read from $DUSKY_OPENROUTER_KEY_FILE
        # (home-manager: dusky.voiceAssistant.apiKeyFile).
        text = ''
          if [ -z "''${OPENROUTER_API_KEY:-}" ] && [ -n "''${DUSKY_OPENROUTER_KEY_FILE:-}" ]; then
            OPENROUTER_API_KEY="$(cat "$DUSKY_OPENROUTER_KEY_FILE" 2>/dev/null || true)"
            export OPENROUTER_API_KEY
          fi
          exec ${voice-python}/bin/python3 ${patched}/tts_stt/voice_assistant/dusky_voice_assistant.py --daemon "$@"
        '';
      })

      # --- Voice Assistant trigger (keybind target): toggle listening ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-voice-assistant";
        runtimeInputs = with pkgs; [libnotify coreutils];
        text = builtins.readFile "${patched}/tts_stt/voice_assistant/dusky_voice_trigger.sh";
      })

      # --- Voice Assistant reset conversation ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-voice-reset";
        runtimeInputs = with pkgs; [libnotify coreutils];
        text = builtins.readFile "${patched}/tts_stt/voice_assistant/dusky_voice_reset.sh";
      })

      # --- Voice Assistant interrupt TTS ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-voice-interrupt";
        runtimeInputs = with pkgs; [coreutils procps];
        text = builtins.readFile "${patched}/tts_stt/voice_assistant/dusky_voice_interrupt.sh";
      })

      # --- STT trigger (keybind target): toggle recording, send audio to daemon ---
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-parakeet-stt";
        runtimeInputs = with pkgs; [wl-clipboard libnotify coreutils pipewire];
        text = ''
          PID_FILE="/tmp/dusky_stt.pid"
          READY_FILE="/tmp/dusky_stt.ready"
          FIFO_PATH="/tmp/dusky_stt.fifo"
          RECORD_PID_FILE="/tmp/dusky_stt_record.pid"

          AUDIO_DIR="/mnt/zram1/parakeet_mic"
          [[ ! -d "/mnt/zram1" ]] && AUDIO_DIR="/tmp/dusky_stt_audio"
          AUDIO_FILE="$AUDIO_DIR/stt_current.wav"

          is_running() {
            [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
          }

          stop_recording() {
            [[ -f "$RECORD_PID_FILE" ]] || return 0
            local RECORD_PID
            RECORD_PID=$(cat "$RECORD_PID_FILE" 2>/dev/null)
            rm -f "$RECORD_PID_FILE"

            if [[ -n "$RECORD_PID" ]]; then
              kill -15 "$RECORD_PID" 2>/dev/null || true
              for _ in $(seq 1 40); do
                kill -0 "$RECORD_PID" 2>/dev/null || break
                sleep 0.05
              done
              kill -9 "$RECORD_PID" 2>/dev/null || true
            fi

            notify-send -a "Parakeet STT" -t 1500 "Processing..." "Transcribing to clipboard"
            printf '%s\n' "$AUDIO_FILE" > "$FIFO_PATH" &
          }

          case "''${1:-}" in
            --kill)
              [[ -f "$RECORD_PID_FILE" ]] && kill "$(cat "$RECORD_PID_FILE")" 2>/dev/null || true
              rm -f "$RECORD_PID_FILE"
              if is_running; then kill "$(cat "$PID_FILE")" 2>/dev/null || true; fi
              rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
              exit 0 ;;
            --status)
              if is_running; then echo "Running (PID: $(cat "$PID_FILE"))"; else echo "Not running"; fi
              exit 0 ;;
            --restart)
              [[ -f "$RECORD_PID_FILE" ]] && kill "$(cat "$RECORD_PID_FILE")" 2>/dev/null || true
              rm -f "$RECORD_PID_FILE"
              is_running && kill "$(cat "$PID_FILE")" 2>/dev/null || true
              rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
              systemctl --user restart dusky-parakeet-stt.service 2>/dev/null || dusky-parakeet-stt-daemon &
              exit 0 ;;
          esac

          # If already recording, stop and transcribe
          if [[ -f "$RECORD_PID_FILE" ]] && kill -0 "$(cat "$RECORD_PID_FILE" 2>/dev/null)" 2>/dev/null; then
            stop_recording
            exit 0
          fi

          # Start daemon if not running
          if ! is_running; then
            rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
            systemctl --user start dusky-parakeet-stt.service 2>/dev/null || dusky-parakeet-stt-daemon &
            for _ in $(seq 1 300); do
              [[ -f "$READY_FILE" ]] && break
              sleep 0.1
            done
            if [[ ! -f "$READY_FILE" ]]; then
              notify-send -a "Parakeet STT" -u critical "Startup Failed" "Daemon not ready after 30s"
              exit 1
            fi
          fi

          # Start recording
          mkdir -p "$AUDIO_DIR"
          pw-record --target @DEFAULT_AUDIO_SOURCE@ --rate 16000 --channels 1 --format=s16 "$AUDIO_FILE" &
          echo $! > "$RECORD_PID_FILE"
          notify-send -a "Parakeet STT" -t 2500 "Listening..." "Speak now. Press again to stop."
        '';
      })
    ];
  }
