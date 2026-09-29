# profiles/home/zsh.nix — the dusky desktop's zsh: oh-my-zsh (git, vi-mode),
# fzf-tab, autosuggestions, syntax highlighting, fzf/zoxide keybinds, lsd/git
# aliases, fastfetch on start. The prompt itself is dusky-nix's matugen-coloured
# oh-my-posh (homeManagerModules.theming).
#
# `dusky-desktop.zsh.<slot>` splices extra lines into fixed points of the
# init script, so a downstream config can add its own aliases/exports without
# reordering anything.
{
  config,
  lib,
  pkgs,
  ...
}: let
  zoxideOptions = lib.concatStringsSep " " config.programs.zoxide.options;
  cfg = config.dusky-desktop.zsh;
  slot = description:
    lib.mkOption {
      type = lib.types.str;
      default = "";
      inherit description;
    };
in {
  options.dusky-desktop.zsh = {
    afterFzfKeys = slot "Lines after fzf's key-bindings.zsh is sourced (e.g. rebinding ^R).";
    afterPath = slot "Lines after PATH is extended.";
    afterClearAlias = slot "Lines after the `c` (clear + fastfetch) alias.";
    afterGitAliases = slot "Lines after the git aliases.";
    beforeFastfetch = slot "Lines just before fastfetch runs.";
  };

  config = {
    # Disable fzf's native zsh integration — it pulls in completion.zsh, which
    # overrides ^I and conflicts with fzf-tab. initExtra sources only
    # key-bindings.zsh (Ctrl-T / Alt-C) instead.
    programs.fzf.enableZshIntegration = lib.mkForce false;
    programs.zoxide.enableZshIntegration = lib.mkForce false;

    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        theme = ""; # Disable oh-my-zsh theme to prevent prompt override
        plugins = [
          "git"

          "vi-mode"
          # "z"
        ];
      };
      plugins = [
        {
          name = "fzf-tab";
          # Use fzf-tab WITHOUT the compiled module — the module's
          # fzf-tab-candidates-generate builtin produces 0 candidates,
          # causing fzf-tab to silently fall back to standard completion.
          src = pkgs.runCommand "fzf-tab-no-module" {} ''
            cp -r ${pkgs.zsh-fzf-tab}/share/fzf-tab $out
            chmod -R u+w $out
            rm -rf $out/modules
          '';
        }
        {
          name = "zsh-autosuggestions";
          src = config.packageSet.zsh-autosuggestions;
          file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "fast-syntax-highlighting";
          src = config.packageSet.zsh-fast-syntax-highlighting;
          file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
        }
        {
          name = "zsh-syntax-highlighting";
          src = config.packageSet.zsh-syntax-highlighting;
          file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
        }
      ];
      initContent = lib.mkOrder 9999 ''
        # macOS: raise the open-file-descriptor soft limit. The default (256) is
        # too low for a nix-darwin evaluation — `darwin-rebuild`/`rebuild` dies
        # mid-eval with "Too many open files" (EMFILE). No-op on Linux.
        ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "ulimit -n 10240"}

        # Override fzf-tab's -ftb-generate-complist — the nixpkgs 1.3.0 version
        # produces 0 candidates in the pure-zsh path, preventing the fzf popup.
        -ftb-generate-complist() {
          local dsuf dpre k _v filepath first_word default_color prefix bs=$'\b'
          local -a list_colors group_colors tcandidates
          local -i same_word=1
          local -A namecolors modecolors

          (( $#_ftb_compcap == 0 )) && return

          -ftb-zstyle -s default-color default_color || default_color='''
          -ftb-zstyle -s prefix prefix || {
            zstyle -m ':completion:*:descriptions' format '*' && prefix='·'
          }
          zstyle -a ":completion:$_ftb_curcontext" list-colors list_colors
          namecolors=(''${(@s:=:)''${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})
          modecolors=(''${(@Ms:=:)''${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})
          (( $#namecolors == 0 && $#modecolors == 0 )) && list_colors=()

          for k _v in "''${(@ps:\2:)_ftb_compcap}"; do
            local -A v=("''${(@0)_v}")
            [[ $v[word] == ''${first_word:=$v[word]} ]] || same_word=0
            dsuf=''' dpre='''
            if (( $+v[realdir] )); then
              filepath=$v[realdir]''${(Q)v[word]}
              [[ -d $filepath ]] && dsuf=/
              if (( $#list_colors )) && [[ -a $filepath || -L $filepath ]]; then
                -ftb-colorize $filepath 2>/dev/null
              fi
            fi
            if (( $+v[group] )); then
              local color=''${group_colors[$v[group]]:-}
              tcandidates+=$v[group]$'\b'$color$prefix$dpre$'\0'$v[group]$'\b'$k$'\0'$dsuf
            else
              tcandidates+="$default_color$dpre"$'\0'"$k"$'\0'"$dsuf"
            fi
          done

          (( same_word )) && tcandidates[2,-1]=()
          tcandidates=("''${(@o)tcandidates}")
          typeset -gUa _ftb_complist=("''${(@)tcandidates//[0-9]#$bs}")
        }

        # fzf-tab integration for cd, ls, and cat
        zstyle ':fzf-tab:complete:(cd|lsd|cat|nvim|rm):*' fzf-preview '[[ -d $realpath ]] && ls --color $realpath || ([[ -f $realpath ]] && cat $realpath || echo "Not a file or directory")'
        zstyle ':fzf-tab:complete:(cd|lsd|cat|nvim|rm):*' fzf-completion-opts --preview-window=down:3:wrap
        zstyle ':fzf-tab:complete:(cd|lsd):*' query-string zoxide query -l

        # Disable zsh menu select so fzf-tab handles completion display
        # (must match oh-my-zsh's specificity: ':completion:*:*:*:*:*')
        zstyle ':completion:*:*:*:*:*' menu no
        # Override oh-my-zsh's matcher-list — its 'l:|=*' subsequence matching
        # causes fzf-tab to find an "unambiguous" prefix and skip the fzf popup
        # entirely (see https://github.com/Aloxaf/fzf-tab/issues/560)
        zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[._-]=* r:|=*'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

        # Global pipe aliases (from common-aliases, minus P which needs pygmentize)
        alias -g H='| head'
        alias -g T='| tail'
        alias -g G='| grep'
        alias -g L='| less'
        alias -g M='| most'
        alias -g LL='2>&1 | less'
        alias -g CA='2>&1 | cat -A'
        alias -g NE='2> /dev/null'
        alias -g NUL='> /dev/null 2>&1'

        bindkey "^[[1;3D" backward-word
        bindkey "^[[1;3C" forward-word
        bindkey -v  # Enable Vim keybindings
        # Restore fzf-tab as tab handler in vi keymaps — bindkey -v resets
        # viins/vicmd ^I to defaults, and oh-my-zsh/fzf bind their own widgets
        bindkey -M viins '^I' fzf-tab-complete
        bindkey -M emacs '^I' fzf-tab-complete

        # fzf Ctrl-T (file into command line) + Alt-C (fuzzy cd). Must come after
        # `bindkey -v`, which resets the keymaps. key-bindings.zsh also grabs ^R,
        # so hand it straight back to atuin below.
        export FZF_CTRL_T_COMMAND='fd --hidden --exclude .git'
        export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
        source ${config.programs.fzf.package}/share/fzf/key-bindings.zsh
        ${cfg.afterFzfKeys}
        export KEYTIMEOUT=1  # Reduce mode switch delay (optional, for faster ESC response)
        export PATH="$HOME/bin:$HOME/Applications:$PATH"
        ${cfg.afterPath}
        alias c="clear && fastfetch"
        ${cfg.afterClearAlias}
        alias ls='lsd'
        alias l='ls -l'
        alias la='ls -a'
        alias lla='ls -la'
        alias lt='ls --tree'
        alias g='git'
        alias gs='git status'
        alias ga='git add'
        alias gc='git commit -m'
        alias gp='git push'
        ${cfg.afterGitAliases}
        ZSH_HIGHLIGHT_STYLES[path]=fg=#8A2BE2
        ${cfg.beforeFastfetch}
        fastfetch
        eval "$(${lib.getExe config.programs.zoxide.package} init zsh ${zoxideOptions})"
      '';
    };
  };
}
