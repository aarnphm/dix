{self}: let
  currentOverlaysDir = ./.;
  dirContents = builtins.readDir currentOverlaysDir;

  nixFileNames = builtins.filter (
    fileName:
      dirContents.${fileName}
      == "regular"
      && fileName != "default.nix"
      && (builtins.substring (builtins.stringLength fileName - 4) 4 fileName) == ".nix"
  ) (builtins.attrNames dirContents);

  sortedNixFileNames = builtins.sort builtins.lessThan nixFileNames;

  loadOverlay = fileName: let
    filePath = currentOverlaysDir + "/${fileName}";
  in
    import filePath {inherit self;};
in
  builtins.map loadOverlay sortedNixFileNames
