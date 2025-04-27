{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  concatStringsSepNewLine = iterables: concatStringsSep "\n" iterables;

  fzfComplete =
    pkgs.writeProgram "fzf_complete_realpath.zsh" {
      bat = lib.getExe pkgs.bat;
      hexyl = lib.getExe pkgs.hexyl;
      tree = lib.getExe pkgs.tree;
      catimg = lib.getExe pkgs.catimg;
      dir = ".";
    }
    ./config/fzf_complete_realpath.zsh.in;
in {
  options.zsh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Zsh for MacOS'';
    };
  };

  config = mkIf config.zsh.enable {
    programs.zsh = {
      enable = true;
      enableVteIntegration = true;
      history = {
        expireDuplicatesFirst = true;
        ignoreDups = true;
        path = "${config.home.homeDirectory}/.local/share/zsh/history";
        save = 100000;
        size = 100000;
      };
      completionInit = ''
        autoload -U compinit && compinit
        autoload -U bashcompinit && bashcompinit
      '';
      initContent = lib.mkOrder 550 ''
        ${lib.getExe pkgs.any-nix-shell} zsh --info-right | source /dev/stdin
        eval "$(${lib.getExe pkgs.oh-my-posh} init zsh --config ${config.xdg.configHome}/oh-my-posh/config.toml)"
        source ${pkgs.dix.zsh-dix}/share/zsh/dix.plugin.zsh
      '';
      plugins = [
        {
          name = "fzf-tab";
          src = pkgs.fetchFromGitHub {
            owner = "Aloxaf";
            repo = "fzf-tab";
            rev = "v1.1.2";
            hash = "sha256-Qv8zAiMtrr67CbLRrFjGaPzFZcOiMVEFLg1Z+N6VMhg=";
          };
        }
        {
          name = "F-Sy-H";
          src = pkgs.fetchFromGitHub {
            owner = "z-shell";
            repo = "F-Sy-H";
            rev = "v1.67";
            hash = "sha256-zhaXjrNL0amxexbZm4Kr5Y/feq1+2zW0O6eo9iZhmi0=";
          };
        }
      ];
      envExtra = ''
        source ${fzfComplete}/fzf_complete_realpath.zsh
      '';
      profileExtra = let
        sites =
          [
            "${pkgs.dix.zsh-dix}/share/zsh/site-functions"
            "${pkgs.zsh-completions}/share/zsh/site-functions"
          ]
          ++ optionals pkgs.stdenv.isDarwin ["/Applications/OrbStack.app/Contents/Resources/completions/zsh"];
      in
        concatStringsSepNewLine [
          (concatStrings (map (sitePath: "fpath+=${sitePath}\n") sites))
        ];
    };
  };
}
