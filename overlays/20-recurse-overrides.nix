final: prev: {
  julia_19 =
    if prev.stdenv.isDarwin
    then null
    else prev.recurseIntoAttrs prev.julia_19;
}
