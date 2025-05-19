{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.helix = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''helix configuration'';
    };
    evil = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Enable evil mode'';
    };
  };

  config = mkIf config.helix.enable {
    programs.helix = {
      enable = true;
      package =
        if config.helix.evil
        then pkgs.evil-helix
        else pkgs.helix;
      extraPackages = with pkgs; [
        # go
        gopls
        golangci-lint-langserver
        delve
        # markdown
        markdown-oxide
        # nix
        nil
        alejandra
        # latex
        texlab
        # ts, tsx, js, jsx, json
        vscode-langservers-extracted
        vtsls
        jq-lsp
        # bash
        bash-language-server
        # python
        ruff
        ty
        basedpyright
        rustup
        # toml
        taplo
        # zig
        zls
      ];
      languages = {
        language-server = {
          vtsls = {
            command = "vtsls";
            args = ["--stdio"];
          };
          ruff = {
            command = "ruff";
            args = ["server"];
          };
          ty = {
            command = "ty";
            args = ["server"];
          };
          basedpyright = {
            command = "basedpyright-langserver";
            args = ["--stdio"];
            config = {
              analysis = {
                autoSearchPaths = true;
                useLibraryCodeForTypes = true;
                diagnosticMode = "openFilesOnly";
              };
            };
          };
        };
        language = [
          {
            name = "lua";
            scope = "source.lua";
            auto-format = false;
          }
          {
            name = "ts";
            scope = "source.ts";
            file-types = ["ts" "tsx" "js" "jsx"];
            auto-format = true;
            indent = {
              tab-width = 2;
              unit = " ";
            };
            language-servers = ["vtsls"];
          }
          {
            name = "nix";
            scope = "source.nix";
            formatter = {command = "alejandra";};
            auto-format = true;
            language-servers = ["nil"];
          }
          {
            name = "python";
            language-id = "python";
            scope = "source.python";
            injection-regex = "python";
            roots = ["pyproject.toml" "setup.py" "ty.toml" "uv.lock" "pyrightconfig.json" "requirements.txt" ".venv/"];
            comment-token = "#";
            file-types = ["py" "ipynb"];
            shebangs = ["python"];
            indent = {
              tab-width = 2;
              unit = " ";
            };
            auto-format = true;
            formatter = {
              command = "ruff";
              args = ["format" "-"];
            };
            language-servers = ["ruff" "ty" "basedpyright"];
          }
        ];
      };
      settings = {
        theme =
          if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
          then "flexoki_dark"
          else "flexoki_light";
        editor =
          lib.optionalAttrs config.helix.evil {
            evil = true;
          }
          // {
            line-number = "relative";
            cursorline = true;
            text-width = 119;
            inline-diagnostics = {
              cursor-line = "warning";
            };
            whitespace = {
              render = {
                space = "all";
                tab = "all";
                nbsp = "none";
                nnbsp = "none";
                newline = "none";
              };
              characters = {
                space = "·";
                nbsp = "⍽";
                nnbsp = "␣";
                tab = "→";
                newline = "⏎";
                tabpad = "·";
              };
            };
            indent-guides = {
              render = true;
              character = "╎";
              skip-levels = 1;
            };
            lsp = {
              display-progress-messages = true;
              display-inlay-hints = true;
            };
          };
        keys = {
          normal = {
            C-s = ":w";
          };
          insert = {
            j = {
              k = "normal_mode";
              j = "normal_mode";
            };
          };
        };
      };
      themes = {
        flexoki_light = let
          tx = "#100F0F";
          tx-2 = "#6F6E69";
          tx-3 = "#B7B5AC";
          ui-3 = "#CECDC3";
          ui-2 = "#DAD8CE";
          ui = "#E6E4D9";
          bg-2 = "#F2F0E5";
          bg = "#FFFCF0";

          re = "#AF3029";
          orr = "#BC5215";
          ye = "#AD8301";
          gr = "#66800B";
          cy = "#24837B";
          bl = "#205EA6";
          pu = "#5E409D";
          ma = "#A02F6F";
        in {
          palette = {
            inherit tx tx-2 tx-3 ui-3 ui-2 ui bg-2 bg;
            inherit re orr ye gr cy bl pu ma;
          };
          "ui.background" = {bg = "bg";};
          "ui.cursor" = {
            fg = "tx";
            bg = "tx-3";
          };
          "ui.cursor.primary" = {
            fg = "bg";
            bg = "tx";
          };
          "ui.cursor.match" = {modifiers = ["bold"];};
          "ui.linenr" = "tx-3";
          "ui.linenr.selected" = "tx";
          "ui.selection" = {bg = "ui-2";};
          "ui.statusline" = {
            fg = "tx";
            bg = "bg-2";
          };
          "ui.statusline.normal" = {
            fg = "bg";
            bg = "bl";
          };
          "ui.statusline.insert" = {
            fg = "bg";
            bg = "orr";
          };
          "ui.statusline.select" = {
            fg = "bg";
            bg = "ma";
          };
          "ui.cursorline" = {bg = "bg-2";};
          "ui.popup" = {
            fg = "tx";
            bg = "bg-2";
          };
          "ui.window" = "tx";
          "ui.help" = {
            fg = "tx";
            bg = "bg";
          };
          "ui.text" = "tx";
          "ui.text.focus" = {
            bg = "bg-2";
            fg = "tx";
          };
          "ui.text.info" = "tx";
          "ui.virtual.whitespace" = "bg-2";
          "ui.virtual.ruler" = {bg = "bg-2";};
          "ui.virtual.inlay-hint" = {
            bg = "bg-2";
            fg = "tx-3";
          };
          "ui.virtual.jump-label" = {
            bg = "bg-2";
            modifiers = ["bold"];
          };
          "ui.menu" = {
            bg = "bg";
            fg = "tx";
          };
          "ui.menu.selected" = {
            bg = "ui";
            fg = "tx";
          };
          "ui.debug" = {
            bg = "bg";
            fg = "orr";
          };
          "ui.highlight.frameline" = {bg = "ye";};
          "diagnostic.hint" = {
            underline = {
              color = "bl";
              style = "curl";
            };
          };
          "diagnostic.info" = {
            underline = {
              color = "bl";
              style = "curl";
            };
          };
          "diagnostic.warning" = {
            underline = {
              color = "ye";
              style = "curl";
            };
          };
          "diagnostic.error" = {
            underline = {
              color = "re";
              style = "curl";
            };
          };
          "hint" = {
            fg = "bl";
            modifiers = ["bold"];
          };
          "info" = {
            fg = "ye";
            modifiers = ["bold"];
          };
          "warning" = {
            fg = "orr";
            modifiers = ["bold"];
          };
          "error" = {
            fg = "re";
            modifiers = ["bold"];
          };

          "attribute" = "ye";
          "type" = "ye";
          "constructor" = "gr";
          "constant" = "pu";
          "constant.builtin" = "ye";
          "string" = "cy";
          "string.regexp" = "orr";
          "string.special" = "ye";
          "comment" = "tx-3";
          "variable" = "tx";
          "variable.builtin" = "ma";
          "variable.other" = "bl";
          "punctuation" = "tx-2";
          "keyword" = "gr";
          "keyword.control" = "re";
          "keyword.control.conditional" = "gr";
          "keyword.control.import" = "ye";
          "keyword.control.return" = "gr";
          "keyword.function" = "gr";
          "keyword.storage.type" = "bl";
          "keyword.storage.modifier" = "bl";
          "operator" = "tx-2";
          "function" = "orr";
          "tag" = "bl";
          "namespace" = "re";

          "markup.heading" = "orr";
          "markup.list" = "ye";
          "markup.bold" = {
            fg = "orr";
            modifiers = ["bold"];
          };
          "markup.italic" = {
            fg = "orr";
            modifiers = ["italic"];
          };
          "markup.strikethrough" = {modifiers = ["crossed_out"];};
          "markup.raw.block" = "orr";
          "markup.link.url" = "bl";
          "markup.link.text" = "ye";
          "markup.link.label" = "gr";
          "markup.quote" = "ye";
          "markup.raw" = "bl";
          "diff.plus" = "gr";
          "diff.minus" = "re";
          "diff.delta" = "ye";
        };
        flexoki_dark = let
          tx = "#CECDC3";
          tx-2 = "#878580";
          tx-3 = "#575653";
          ui-3 = "#403E3C";
          ui-2 = "#343331";
          ui = "#282726";
          bg-2 = "#1C1B1A";
          bg = "#100F0F";

          re = "#D14D41";
          orr = "#DA702C";
          ye = "#D0A215";
          gr = "#879A39";
          cy = "#3AA99F";
          bl = "#4385BE";
          pu = "#8B7EC8";
          ma = "#CE5D97";
        in {
          inherits = "flexoki_light";
          palette = {
            inherit tx tx-2 tx-3 ui-3 ui-2 ui bg-2 bg;
            inherit re orr ye gr cy bl pu ma;
          };
        };
      };
    };
  };
}
