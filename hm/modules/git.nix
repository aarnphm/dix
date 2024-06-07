{ config, lib, pkgs, ... }:
with lib;
{
  options.git = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Git configuration'';
    };
  };

  config = mkIf config.git.enable {
    programs = {
      git = {
        enable = true;
        package = pkgs.gitFull;
        userEmail = "29749331+aarnphm@users.noreply.github.com";
        userName = "Aaron Pham";
        lfs = {
          enable = true;
        };
        signing = {
          key = "D689D1C7F18B4D1D";
          signByDefault = true;
        };
        extraConfig = {
          format = {
            pretty = "%C(auto)%h - %s%d%n%+b%+N(%G?) %an <%ae> (%C(blue)%ad%C(auto))%n";
          };
          submodule = {
            recurse = true;
          };
          pull = {
            rebase = true;
          };
          commit = {
            sign = true;
          };
          merge = {
            conflictstyle = "diff3";
          };
          push = {
            default = "current";
          };
          diff = {
            colorMoved = "default";
          };
          rebase = {
            autosquash = true;
            autostash = true;
          };
          init = {
            defaultBranch = "main";
          };
          branch = {
            sort = "-committerdate";
          };
          core = {
            # Treat spaces before tabs and all kinds of trailing whitespace as an error.
            # [default] trailing-space: looks for spaces at the end of a line
            # [default] space-before-tab: looks for spaces before tabs at the beginning of a line
            whitespace = "space-before-tab,-indent-with-non-tab,trailing-space";

            # Make `git rebase` safer on macOS.
            # More info: <http://www.git-tower.com/blog/make-git-rebase-safe-on-osx/>
            trustctime = false;

            excludesFile = "${pkgs.emulators}/git/.gitignore";

            # Prevent showing files whose names contain non-ASCII symbols as unversioned.
            # http://michael-kuehnel.de/git/2014/11/21/git-mac-osx-and-german-umlaute.html
            precomposeunicode = false;
            # Speed up commands involving untracked files such as `git status`.
            # https://git-scm.com/docs/git-update-index#_untracked_cache
            untrackedCache = true;
            editor = "${pkgs.neovim-developer}/bin/nvim";
            pager = "${pkgs.delta}/bin/delta";

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
            dark = true;
            syntax-theme = "Dracula";

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

          tree = "forest --pretty=format:\"%C(red)%h %C(magenta)(%ar) %C(blue)%an %C(reset)%s\" --style=15 --reverse";

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
          rebc = "!f() { git add .; git rebase --continue; }; f";

          # view last commit message
          lone = "log -1 --pretty=%B";

          # View the current working tree status using the short format.
          s = "status";
          ss = "status -s";
          st = "status -sb";
          si = "status --ignored";

          # Show the diff between the latest commit and the current state.
          d = ''!"git diff-index --quiet HEAD -- || clear; git --no-pager diff --patch-with-stat"'';

          dp = "diff --patience -w";

          # `git di $number` shows the diff between the state `$number` revisions ago and the current state.
          di = ''!"d() { git diff --patch-with-stat HEAD~$1; }; git diff-index --quiet HEAD -- || clear; d"'';

          # Pull in remote changes for the current repository and all its submodules.
          pre = "pull --signoff --recurse-submodules";
          p = "pull --signoff --gpg-sign --rebase";
          pp = "!f() { git fetch \"$1\" \"$2\" && git pull \"$1\" \"$2\" && git remote prune \"$1\"; }; f";
          pa = "pull --all --signoff --gpg-sign";
          cnb = "checkout --track -b";

          # fetch upstream and push
          pup = "!f() { git pull upstream main; git push -u origin main; }; f";

          # Clone a repository including all submodules.
          cr = "clone --recursive";
          c = "clone";
          clone-worktree = "!sh $HOME/.local/bin/git-worktree-setup";

          # worktree alias
          wa = "worktree add";
          wr = "worktree remove";
          wl = "worktree list";

          # Commit all changes.
          ca = "!git add -A && git commit -S -sav";
          cm = "commit -S --signoff -sv";
          cmm = "commit -S --signoff -svm";

          # Switch to a branch, creating it if necessary.
          go = "!f() { git checkout -b \"$1\" 2> /dev/null || git checkout \"$1\"; }; f";

          # Show verbose output about tags, branches or remotes
          tags = "tag -l";
          branches = "branch -va";
          remotes = "remote --verbose";
          reprune = "remote prune";

          # List aliases.
          aliases = "config --get-regexp alias";

          # quick push
          pushall = "!p() { git add . && git commit -S -sm \"$1\" && git push; }; p";

          # Amend the currently staged files to the latest commit.
          amend = "commit --amend --reuse-message=HEAD";

          # Credit an author on the latest commit.
          credit = "!f() { git commit -S -s --amend --author \"$1 <$2>\" -C HEAD; }; f";

          # Interactive rebase with the given number of latest commits.
          reb = "rebase -i -S --signoff";
          ra = "rebase --abort";
          rc = "rebase --continue";
          ri = "rebase --interactive";
          rup = "rebase -i --signoff upstream/main";

          # Remove the old tag with this name and tag the latest commit with it.
          retag = "!r() { git tag -d $1 && git push origin :refs/tags/$1 && git tag $1; }; r";

          # Find branches containing commit
          fb = "!f() { git branch -a --contains $1; }; f";

          # Find tags containing commit
          ft = "!f() { git describe --always --contains $1; }; f";

          # Find commits by source code
          fc = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short -S$1; }; f";

          # Find commits by commit message
          fm = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep=$1; }; f";

          # Remove branches that have already been merged with main.
          # a.k.a. ‘delete merged’
          dm = "!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d";

          # checkout files from upstream/main
          revm = "!f() { git checkout upstream/main -- $@; git add $@; git commit -sm \"chore: revert changes from upstream/main\n\nreverted changes: $@\"; git push -f; }; f";

          # clean xdf
          pxdf = "!f() { git clean -fdx --exclude 'venv' --exclude 'tools' --exclude 'bazel-*'; pip install -e . -vvv; }; f";
          bpxdf = "!f() { bazel clean && git clean -fdx --exclude 'venv' --exclude 'tools'; pip install -e .[all] -vvv; }; f";
          xdf = ''clean -xdf --exclude "venv" --exclude "bazel-*"'';

          # List contributors with number of commits.
          contributors = "shortlog --summary --numbered";

          # Show the user email for the current repository.
          whoami = "config user.email";
        };
      };
    };
  };
}
