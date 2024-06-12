{ config, lib, pkgs, ... }:
let
  zedKeymap = [
    {
      context = "menu";
      bindings = {
        "ctrl-j" = "menu::SelectNext";
        "ctrl-k" = "menu::SelectPrev";
      };
    }
    {
      context = "Workspace";
      bindings = {
        "cmd-?" = null;
      };
    }
    {
      context = "Editor && showing_completions";
      bindings = {
        "tab" = null;
      };
    }
    {
      context = "Editor";
      bindings = {
        "cmd-[" = null;
        "cmd-]" = null;
      };
    }
    {
      context = "Pane && !VimWaiting";
      bindings = {
        ", v s" = "pane::SplitRight";
      };
    }
    {
      context = "Editor";
      bindings = {
        "ctrl-j" = null;
      };
    }
    {
      context = "Editor && vim_mode == normal && !VimWaiting &&!menu";
      bindings = {
        "J" = "editor::JoinLines";
      };
    }
    {
      context = "Editor && vim_mode == insert";
      bindings = {
        "j j" = [ "workspace::SendKeystrokes" "escape" ];
        "j k" = [ "workspace::SendKeystrokes" "escape" ];
      };
    }
    {
      context = "Editor && VimControl && !VimWaiting && !menu";
      bindings = {
        ";" = "command_palette::Toggle";
        ":" = "vim::RepeatFind";
        "K" = "editor::Hover";
        "ctrl-x" = "pane::CloseActiveItem";
        "g r" = "editor::Rename";
        "g R" = "editor::FindAllReferences";
        ">" = "editor::Indent";
        "<" = "editor::Outdent";
        "] d" = "editor::GoToDiagnostic";
        "[ d" = "editor::GoToPrevDiagnostic";
        "space space f" = "editor::Format";
        ", v s" = "editor::SplitSelectionIntoLines";
        "space v" = "editor::ToggleComments";
        "F" = [
          "vim::PushOperator"
          {
            FindBackward = {
              after = false;
            };
          }
        ];
        "T" = [
          "vim::PushOperator"
          {
            FindBackward = {
              after = true;
            };
          }
        ];
      };
    }
    {
      context = "Editor && vim_mode == visual && !menu";
      bindings = {
        "J" = "editor::MoveLineDown";
        "K" = "editor::MoveLineUp";
      };
    }
    {
      context = "Dock && VimControl";
      bindings = {
        "ctrl-w h" = [ "workspace::ActivatePaneInDirection" "Left" ];
        "ctrl-w l" = [ "workspace::ActivatePaneInDirection" "Right" ];
        "ctrl-w k" = [ "workspace::ActivatePaneInDirection" "Up" ];
        "ctrl-w j" = [ "workspace::ActivatePaneInDirection" "Down" ];
      };
    }
    {
      context = "ProjectPanel && not_editing";
      bindings = {
        ";" = "command_palette::Toggle";
        "o" = "project_panel::NewFile";
        "/" = "project_panel::NewSearchInDirectory";
        "shift-o" = "project_panel::NewDirectory";
        "enter" = "project_panel::Open";
        "escape" = "project_panel::ToggleFocus";
        "h" = "project_panel::CollapseSelectedEntry";
        "j" = "menu::SelectNext";
        "k" = "menu::SelectPrev";
        "l" = "project_panel::ExpandSelectedEntry";
        "shift-l" = "project_panel::Open";
        "shift-d" = "project_panel::Delete";
        "shift-r" = "project_panel::Rename";
      };
    }
  ];

  zedConfig = {
    theme = "Rosé Pine Dawn";
    buffer_font_family = "BerkeleyMono Nerd Font Mono";
    telemetry = {
      diagnostics = true;
      metrics = false;
    };
    vim_mode = true;
    ui_font_size = 15;
    use_autoclose = false;
    buffer_font_size = 15;
    preferred_line_length = 119;
    relative_line_numbers = true;
    ensure_final_newline_on_save = false;
    inlay_hints = {
      enabled = true;
    };
    assistant = {
      button = false;
    };
    chat_panel = {
      enabled = false;
    };
    lsp = {
      gopls = {
        initialization_options = {
          hints = {
            assignVariableTypes = true;
            compositeLiteralFields = true;
            compositeLiteralTypes = true;
            constantValues = true;
            functionTypeParameters = true;
            parameterNames = true;
            rangeVariableType = true;
          };
        };
      };
      Lua = {
        initialization_options = {
          Lua = {
            runtime = {
              version = "LuaJIT";
              special = {
                reload = "require";
              };
            };
            workspace = {
              checkThirdParty = "Disable";
            };
            telemetry = {
              enable = false;
            };
            semantic = {
              enable = true;
            };
            completion = {
              workspaceWord = true;
              callSnippet = "Both";
            };
            hover = {
              expandAlias = false;
            };
            hint = {
              enable = true;
              setType = false;
              paramType = true;
              paramName = "Disable";
              semicolon = "Disable";
              arrayIndex = "Disable";
            };
            doc = {
              privateName = [ "^_" ];
            };
            type = {
              castNumberToInteger = true;
            };
            diagnostics = {
              disable = [ "incomplete-signature-doc" "trailing-space" ];
              groupSeverity = {
                strong = "Warning";
                strict = "Warning";
              };
              groupFileStatus = {
                ambiguity = "Opened";
                await = "Opened";
                codestyle = "None";
                duplicate = "Opened";
                global = "Opened";
                luadoc = "Opened";
                redefined = "Opened";
                strict = "Opened";
                strong = "Opened";
                "type-check" = "Opened";
                unbalanced = "Opened";
                unused = "Opened";
              };
              unusedLocalExclude = [ "_*" ];
            };
            format = {
              enable = true;
              defaultConfig = {
                indent_style = "space";
                indent_size = "2";
                continuation_indent_size = "2";
              };
            };
          };
        };
      };
    };
    autosave = "on_focus_change";
    auto_update = false;
    file_scan_exclusions = [
      "tsconfig.tsbuildinfo"
      "**/node_modules"
      "**/target"
      "**/dist"
      "**/__pycache__"
      "**/.git"
      "**/.svn"
      "**/.hg"
      "CVS"
      "**/.DS_Store"
      "**/Thumbs.db"
      "**/.classpath"
      "**/.settings"
      "**/.mypy_cache"
      "**/.ruff_cache"
      "**/.quartz-cache"
      "**/.venv"
      "**/.vercel"
      "**/venv"
    ];
    journal = {
      path = "${config.home.homeDirectory}/workspace/garden/content";
    };
    tab_size = 2;
    language_overrides = {
      Markdown = {
        format_on_save = "off";
      };
      Python = {
        format_on_save = "off";
        formatter = {
          external = {
            command = "ruff";
            arguments = [ "format" "-" ];
          };
        };
      };
    };
  };
in
with lib; {
  options.zed = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Zed configuration'';
    };
  };

  config = mkIf (config.zed.enable && pkgs.stdenv.isDarwin) {
    xdg = {
      enable = true;
      configFile = {
        "zed/keymap.json".source = pkgs.writeText "zed-keymap" (builtins.toJSON zedKeymap);
        "zed/settings.json".source = pkgs.writeText "zed-settings" (builtins.toJSON zedConfig);
      };
    };
  };
}
