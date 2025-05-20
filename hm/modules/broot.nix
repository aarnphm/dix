{
  config,
  lib,
  pkgs,
  ...
}: let
  package = pkgs.broot;

  jsonFormat = pkgs.formats.json {};

  shellInit = shell:
  # Using mkAfter to make it more likely to appear after other
  # manipulations of the prompt.
    lib.mkAfter ''
      source ${
        pkgs.runCommand "br.${shell}" {
          nativeBuildInputs = [package];
        } "broot --print-shell-function ${shell} > $out"
      }
    '';

  settings = {
    modal = true;
    default_flags = "-gh";
    syntax_theme = "GitHub";
    enable_kitty_keyboard = true;
    icon_theme = "nerdfont";
    special_paths = {
      ".git" = {
        show = "never";
        list = "never";
      };
      ".ruff_cache" = {
        show = "never";
        list = "never";
      };
      ".mypy_cache" = {
        show = "never";
        list = "never";
      };
      "~/.config" = {
        show = "always";
        list = "always";
      };
    };
    imports = [
      "verbs.hjson"
      {
        file = "skins/flexoki-dark.hjson";
        luma = ["dark" "unknown"];
      }
      {
        file = "skins/flexoki-light.hjson";
        luma = ["light"];
      }
    ];
    transformers = [
      {
        input_extensions = ["pdf"];
        output_extension = "png";
        mode = "image";
        command = ["mutool" "draw" "-w" "1000" "-o" "{output-path}" "{input-path}"];
      }
      {
        input_extensions = ["json"];
        output_extension = "json";
        mode = "text";
        command = ["jq"];
      }
    ];
    verbs = [
      {
        name = "open";
        key = "enter";
        execution = "$EDITOR {file}";
        working_dir = "{root}";
        leave_broot = true;
      }
    ];
  };
in
  with lib; {
    options.broot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''broot configuration'';
      };
    };

    config = mkIf config.broot.enable {
      home.packages = [package];

      programs.zsh.initContent = shellInit "zsh";

      xdg.configFile.broot = {
        recursive = true;
        source = pkgs.symlinkJoin {
          name = "xdg.configFile.broot";
          paths = [
            # Copy all files under /resources/default-conf
            "${package.src}/resources/default-conf"

            # Dummy file to prevent broot from trying to reinstall itself
            (pkgs.writeTextDir "launcher/installed-v1" "")
          ];
          postBuild = ''
            rm $out/conf.hjson
            ${lib.getExe pkgs.jq} --slurp add > $out/conf.hjson \
              <(${lib.getExe pkgs.hjson-go} -c ${package.src}/resources/default-conf/conf.hjson) \
              ${jsonFormat.generate "broot-config.json" settings}
            ${lib.getExe pkgs.hjson-go} -c ${./config/broot/flexoki-dark.hjson} > $out/skins/flexoki-dark.hjson
            ${lib.getExe pkgs.hjson-go} -c ${./config/broot/flexoki-light.hjson} > $out/skins/flexoki-light.hjson
          '';
        };
      };
    };
  }
