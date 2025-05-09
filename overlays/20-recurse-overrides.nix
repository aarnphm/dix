self: super: {
  dix = super.recurseIntoAttrs (super.dix or {});

  julia_19 =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.julia_19;
}
