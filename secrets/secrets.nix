let
  pubkeys = import ../dix/pubkeys.nix;
in
{
  "aarnphm-id_ed25519-github.age".publicKeys = pubkeys.aarnphm;
  "paperspace-id_ed25519-github.age".publicKeys = pubkeys.aarnphm;
}
