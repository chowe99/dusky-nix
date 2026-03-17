{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=60";
    };
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 25000;
      path = "${config.home.homeDirectory}/.zsh_history";
      append = true;
      ignoreSpace = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    historySubstringSearch.enable = true;

    shellAliases = {
      # Safety
      cp = "cp -iv";
      mv = "mv -iv";
      rm = "rm -I";
      ln = "ln -v";

      # Filesystem
      disk_usage = "sudo btrfs filesystem usage /";
      df = "df -hT";

      # eza (if installed, handled by home.packages)
      ls = "eza --icons --group-directories-first";
      ll = "eza --icons --group-directories-first -l --git";
      la = "eza --icons --group-directories-first -la --git";
      lt = "eza --icons --group-directories-first --tree --level=2";

      # Tool aliases
      diff = "delta --side-by-side";
      grep = "grep --color=auto";
      egrep = "egrep --color=auto";
      fgrep = "fgrep --color=auto";
      ncdu = "gdu";

      # NixOS specific
      rebuild = "sudo nixos-rebuild switch --flake ~/dusky-refactor#default";
      rebuild-test = "sudo nixos-rebuild test --flake ~/dusky-refactor#default";
      nix-clean = "sudo nix-collect-garbage -d && nix-collect-garbage -d";

      # Dusky theme shortcuts
      darkmode = "dusky-theme-ctl set --mode dark";
      lightmode = "dusky-theme-ctl set --mode light";

      # Drive management
      unlock = "dusky-drive-manager unlock";
      lock = "dusky-drive-manager lock";

      # IO monitor
      io_drives = "dusky-io-monitor";
    };

    initExtraFirst = ''
      # Exit early if not interactive
      [[ -o interactive ]] || return
    '';

    completionInit = ''
      # Optimized compinit: Only regenerate cache once every 24 hours
      autoload -Uz compinit
      if [[ -n ''${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh-24) ]]; then
        compinit -C
      else
        compinit
        touch "''${ZDOTDIR:-$HOME}/.zcompdump"
      fi
    '';

    initExtra = ''
      # Completion styles
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*:descriptions' format '%B%d%b'
      zstyle ':completion:*' group-name ""
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # Shell options
      setopt EXTENDED_GLOB
      setopt GLOB_DOTS
      setopt NO_CASE_GLOB
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
      setopt INTERACTIVE_COMMENTS

      # Vi mode
      bindkey -v
      export KEYTIMEOUT=40

      # Edit command line in Neovim
      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey -M vicmd v edit-command-line

      # History search with Up/Down
      autoload -U history-search-end
      zle -N history-beginning-search-backward-end history-search-end
      zle -N history-beginning-search-forward-end history-search-end
      bindkey "''${terminfo[kcuu1]:-^[[A}" history-beginning-search-backward-end
      bindkey "''${terminfo[kcud1]:-^[[B}" history-beginning-search-forward-end

      # --- Functions ---

      # Weather query
      wthr() {
          if [[ "$1" == "-s" ]]; then
              shift
              local location="''${(j:+:)@}"
              curl "wttr.in/''${location}?format=%c+%t"
          else
              local location="''${(j:+:)@}"
              curl "wttr.in/''${location}"
          fi
      }

      # Waydroid pictures mount
      waydroid_bind() {
          local target="$HOME/.local/share/waydroid/data/media/0/Pictures"
          local source="/mnt/zram1"
          sudo umount -R "$target" 2>/dev/null || true
          if [[ -d "$source" ]]; then
              sudo mount --bind "$source" "$target"
              echo "Successfully bound $source to Waydroid Pictures."
          else
              echo "Error: Source $source does not exist."
              return 1
          fi
      }

      # Intercept sudo nvim -> sudoedit
      sudo() {
          if [[ "$1" == "nvim" ]]; then
              shift
              if [[ $# -eq 0 ]]; then
                  echo "Error: sudoedit requires a filename."
                  return 1
              fi
              command sudoedit "$@"
          else
              command sudo "$@"
          fi
      }

      # Yazi: change cwd on exit
      function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
          yazi "$@" --cwd-file="$tmp"
          if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
              builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
      }

      # mkdir + cd
      mkcd() {
          mkdir -p "$1" && cd "$1"
      }

      # Windows 10 KVM Manager
      win() {
          local vm="win10"
          local shm_file="/dev/shm/looking-glass"
          local lg_cmd="looking-glass-client -f ''${shm_file} -m KEY_F6"

          case "$1" in
              start) echo -e "\e[34m[WIN10]\e[0m Starting VM..."; sudo virsh start "$vm" ;;
              stop|shutdown) echo -e "\e[34m[WIN10]\e[0m Sending shutdown..."; sudo virsh shutdown "$vm" ;;
              kill|destroy) echo -e "\e[31m[WIN10]\e[0m Force destroying VM..."; sudo virsh destroy "$vm" ;;
              reboot) echo -e "\e[34m[WIN10]\e[0m Rebooting VM..."; sudo virsh reboot "$vm" ;;
              view|lg|show)
                  if [ -f "$shm_file" ]; then
                      echo -e "\e[34m[WIN10]\e[0m Launching Looking Glass..."
                      eval "$lg_cmd"
                  else
                      echo -e "\e[31m[ERROR]\e[0m SHM file not found. Is the VM running?"
                  fi ;;
              launch|play)
                  echo -e "\e[34m[WIN10]\e[0m Starting VM + Looking Glass..."
                  sudo virsh start "$vm" 2>/dev/null
                  echo -e "\e[34m[WIN10]\e[0m Waiting for Shared Memory..."
                  local timeout=30
                  while [ ! -f "$shm_file" ] && [ $timeout -gt 0 ]; do
                      sleep 1; ((timeout--))
                  done
                  if [ -f "$shm_file" ]; then
                      echo -e "\e[34m[WIN10]\e[0m Ready!"; eval "$lg_cmd"
                  else
                      echo -e "\e[31m[ERROR]\e[0m Timed out."
                  fi ;;
              status) sudo virsh domstate "$vm" ;;
              edit) sudo virsh edit "$vm" ;;
              *) echo "Usage: win {start|shutdown|destroy|reboot|view|launch|status|edit}" ;;
          esac
      }

      _win_completion() {
          local -a commands
          commands=('start' 'shutdown' 'destroy' 'reboot' 'view' 'launch' 'status' 'edit')
          _describe 'command' commands
      }
      compdef _win_completion win

      # Auto login to Hyprland on TTY1
      if [[ -z "$DISPLAY" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
          if uwsm check may-start; then
              exec uwsm start hyprland.desktop
          fi
      fi
    '';
  };

  # FZF integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

}
