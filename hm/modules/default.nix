let
  readDirRecursive = dir: let
    dirContents = builtins.readDir dir;
    subDirs = builtins.filter (name: dirContents.${name} == "directory") (builtins.attrNames dirContents);
    files = builtins.filter (name: dirContents.${name} == "regular" && builtins.match ".*\.nix" name != null && name != "default.nix") (builtins.attrNames dirContents);
  in
    files ++ builtins.concatMap (d: readDirRecursive "${dir}/${d}") subDirs;

  moduleFiles = readDirRecursive ./.;
in {
  imports = map (file: ./. + "/${file}") moduleFiles;
}
