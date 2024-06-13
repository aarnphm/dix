let
  # Get a list of all .nix files in the current directory
  moduleFiles =
    builtins.filter
    (f: f != "default.nix")
    (builtins.attrNames (builtins.readDir ./.));
in {
  imports = map (file: ./. + "/${file}") moduleFiles;
}
