self: super: {
  dix =
    super.dix
    or {}
    // super.lib.optionalAttrs super.stdenv.isDarwin {
      Splice = super.callPackage (import ./packages/darwin/Splice.app) {};
    };
}
