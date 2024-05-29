self: super:
{
  dix = super.dix or { } // {
    sketchybar = super.sketchybar.overrideAttrs (oldAttrs: {
      installPhase = oldAttrs.installPhase + ''
        mkdir -p $out/plugins
        cp -r ./plugins $out
      '';
    });
  };
}

