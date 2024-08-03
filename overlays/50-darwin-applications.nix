self: super: {
  dix =
    super.dix
    or {}
    // super.lib.optionalAttrs super.stdenv.isDarwin {
      OrbStack = super.callPackage (import ./packages/darwin/OrbStack.app) {};
      Splice = super.callPackage (import ./packages/darwin/Splice.app) {};
    };
}
