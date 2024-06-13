let
  pubkeys = {
    aarnphm = "age1mv4a6aj4xv04s6kfgyjeyw2r80ac43mx8aujdl5lgwd6qy2mvymqh2yuce";
    paperspace = "age1at9s6w2znasalcn8ghfvhq39x4g54pl0x7wf6usrn3g5xmleuscqwn3nle";
  };
in {
  "secrets/aarnphm-id_ed25519-github.age".publicKeys = pubkeys.aarnphm;
  "secrets/paperspace-id_ed25519-github.age".publicKeys = pubkeys.paperspace;
}
