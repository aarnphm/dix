{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  gitPackage = pkgs.git;
  gitBin = getExe gitPackage;
in {
  options.git = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Git configuration'';
    };
  };

  config = mkIf config.git.enable {
    programs = {
      gh = {
        enable = true;
        gitCredentialHelper = {
          enable = true;
          hosts = ["https://github.com" "https://gist.github.com"];
        };
        settings = {
          editor = "nvim";
          git_protocol = "ssh";
          aliases = {
            co = "pr checkout";
            pv = "pr view";
          };
          pager = "${lib.getExe pkgs.bat} --paging=always --color=always --decorations=never --";
        };
      };
      git = {
        enable = true;
        package = gitPackage;
        userEmail = "contact@aarnphm.xyz";
        userName = "Aaron Pham";
        lfs = {
          enable = true;
        };
        signing = {
          key =
            if pkgs.stdenv.isDarwin
            then "18974753009D2BFA"
            else "DEFC62745C797989";
          signByDefault = false;
        };
        ignores = [
          ".git"
          ".vim"
          "*.iml"
          "*.ipr"
          "*.iws"
          ".idea/"
          "out/"
          "local.properties"
          "/.ipynb_checkpoints"
          "*.o"
          "*.so"
          "*.7z"
          "*.dmg"
          "*.gz"
          "*.iso"
          "*.rar"
          "*.tar"
          "*.zip"
          "log/"
          "*.log"
          "*.sql"
          "*.sqlite"
          ".DS_Store"
          ".DS_Store?"
          "ehthumbs.db"
          "Icon?"
          "Thumbs.db"
          "**/__pycache__/**"
          "*.py[cod]"
          "*$py.class"
          ".Python"
          "build/**"
          "dist/**"
          "sdist/"
          "wheels/"
          "node_modules/"
        ];
        extraConfig = {
          format = {
            pretty = "%C(auto)%h - %s%d%n%+b%+N(%G?) %an <%ae> (%C(blue)%ad%C(auto))%n";
          };
          submodule = {recurse = true;};
          pull = {rebase = true;};
          commit = {
            sign = true;
            verbose = true;
          };
          push = {default = "current";};
          diff = {colorMoved = "default";};
          color = {ui = "auto";};
          column = {ui = "auto";};
          init = {defaultBranch = "main";};
          merge = {conflictstyle = "diff3";};
          rebase = {
            autosquash = true;
            autostash = true;
          };
          branch = {
            sort = "-committerdate";
            autosetuprebase = "always";
          };
          core = {
            # Treat spaces before tabs and all kinds of trailing whitespace as an error.
            # [default] trailing-space: looks for spaces at the end of a line
            # [default] space-before-tab: looks for spaces before tabs at the beginning of a line
            whitespace = "space-before-tab,-indent-with-non-tab,trailing-space";

            # Make `git rebase` safer on macOS.
            # More info: <http://www.git-tower.com/blog/make-git-rebase-safe-on-osx/>
            trustctime = false;

            # Prevent showing files whose names contain non-ASCII symbols as unversioned.
            # http://michael-kuehnel.de/git/2014/11/21/git-mac-osx-and-german-umlaute.html
            precomposeunicode = false;
            # Speed up commands involving untracked files such as `git status`.
            # https://git-scm.com/docs/git-update-index#_untracked_cache
            untrackedCache = true;
            editor = "${lib.getExe pkgs.neovim}";

            autocrlf = "input";
          };
        };
        delta = {
          enable = true;
          options = {
            features = "decorations";
            navigate = true;
            side-by-side = true;
            line-numbers = true;
            syntax-theme =
              if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
              then "gruvbox-dark"
              else "gruvbox-light";

            interactive = {
              keep-plus-minus-markers = false;
            };

            decorations = {
              commit-decoration-style = "blue ol";
              commit-style = "raw";
              file-style = "omit";
              hunk-header-decoration-style = "blue box";
              hunk-header-file-style = "red";
              hunk-header-line-number-style = "#067a00";
              hunk-header-style = "file line-number syntax";
            };
          };
        };
        aliases = {
          # quick commit
          ci = "commit";

          # update current index with keeping the files minimal
          skip = "update-index --skip-worktree";
          noskip = "update-index --no-skip-worktree";

          tree = ''forest --pretty=format:"%C(red)%h %C(magenta)(%ar) %C(blue)%an %C(reset)%s" --style=15 --reverse'';

          # get branch
          br = "branch -vv";

          b = "blame --dense --color-lines";

          # Long log
          ll = "log --graph --decorate --oneline --all";
          l = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          lgs = "log --oneline --abbrev-commit --all --graph --decorate --color";
          lg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";

          # reset config
          nvm = "reset --soft HEAD~1";

          # update tags
          fut = "fetch upstream --tags";

          # rebase continue
          rebc = "!f() { ${gitBin} add .; ${gitBin} rebase --continue; }; f";

          # view last commit message
          lone = "log -1 --pretty=%B";

          # View the current working tree status using the short format.
          s = "status";
          ss = "status -s";
          st = "status -sb";
          si = "status --ignored";

          # Show the diff between the latest commit and the current state.
          d = "!${gitBin} diff-index --quiet HEAD -- || clear; ${gitBin} --no-pager diff --patch-with-stat";

          dp = "diff --patience -w";

          # `git di $number` shows the diff between the state `$number` revisions ago and the current state.
          di = "!d() { ${gitBin} diff --patch-with-stat HEAD~$1; }; ${gitBin} diff-index --quiet HEAD -- || clear; d";

          # Pull in remote changes for the current repository and all its submodules.
          pre = "pull --signoff --recurse-submodules";
          p = "pull --signoff --gpg-sign --rebase";
          pp = ''!f() { ${gitBin} fetch "$1" "$2" && ${gitBin} pull "$1" "$2" && ${gitBin} remote prune "$1"; }; f'';
          pa = "pull --all --signoff --gpg-sign";
          cnb = "checkout --track -b";

          # fetch upstream and push
          pup = "!f() { ${gitBin} pull upstream main; ${gitBin} push -u origin main; }; f";

          # Clone a repository including all submodules.
          cr = "clone --recursive";
          c = "clone";

          # worktree alias
          wa = "worktree add";
          wr = "worktree remove";
          wl = "worktree list";

          # Commit all changes.
          ca = "!${gitBin} add -A && ${gitBin} commit -S -sav";
          cm = "commit -S --signoff -sv";
          cmm = "commit -S --signoff -svm";

          # Switch to a branch, creating it if necessary.
          go = ''!f() { ${gitBin} checkout -b "$1" 2> /dev/null || ${gitBin} checkout "$1"; }; f'';

          # Show verbose output about tags, branches or remotes
          tags = "tag -l";
          branches = "branch -va";
          remotes = "remote --verbose";
          reprune = "remote prune";

          # List aliases.
          aliases = "config --get-regexp alias";

          # quick push
          pushall = ''!p() { ${gitBin} add . && ${gitBin} commit -S -sm "$1" && ${gitBin} push; }; p'';

          # Amend the currently staged files to the latest commit.
          amend = "commit --amend --reuse-message=HEAD";

          # Credit an author on the latest commit.
          credit = "!f() { ${gitBin} commit -S -s --amend --author \"$1 <$2>\" -C HEAD; }; f";

          # Interactive rebase with the given number of latest commits.
          reb = "rebase -i -S --signoff";
          ra = "rebase --abort";
          rc = "rebase --continue";
          ri = "rebase --interactive";
          rup = "rebase -i --signoff upstream/main";

          # Remove the old tag with this name and tag the latest commit with it.
          retag = "!r() { ${gitBin} tag -d $1 && ${gitBin} push origin :refs/tags/$1 && ${gitBin} tag $1; }; r";

          # Find branches containing commit
          fb = "!f() { ${gitBin} branch -a --contains $1; }; f";

          # Find tags containing commit
          ft = "!f() { ${gitBin} describe --always --contains $1; }; f";

          # Find commits by source code
          fc = "!f() { ${gitBin} log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short -S$1; }; f";

          # Find commits by commit message
          fm = "!f() { ${gitBin} log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep=$1; }; f";

          # Remove branches that have already been merged with main.
          # a.k.a. ‘delete merged’
          dm = "!${gitBin} branch --merged | grep -v '\\*' | xargs -n 1 ${gitBin} branch -d";

          # List contributors with number of commits.
          contributors = "shortlog --summary --numbered";

          # Show the user email for the current repository.
          whoami = "config user.email";
        };
      };
    };
  };
}
