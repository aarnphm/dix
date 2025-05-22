{
  config,
  lib,
  ...
}:
with lib; {
  options.ghostty = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''ghostty configuration'';
    };
  };

  config = mkIf config.ghostty.enable {
    programs = {
      ghostty = {
        enable = true;
        package = null;
        enableZshIntegration = true;
        settings = {
          theme =
            if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
            then "flexoki-dark"
            else "flexoki-light";
          font-family = "BerkeleyMono Nerd Font Mono";
          keybind = [
            "cmd+s=new_split:left"
            "shift+cmd+s=new_split:up"
            "global:cmd+shift+grave_accent=toggle_quick_terminal"
          ];
          cursor-style = "block";
          macos-icon = "paper";
          macos-icon-frame = "chrome";
          macos-titlebar-style = "tabs";
          scrollback-limit = 40000;
          auto-update = "download";
          auto-update-channel = "tip";
          term = "xterm-256color";
          quick-terminal-position = "center";
        };
      };
    };
  };
}
