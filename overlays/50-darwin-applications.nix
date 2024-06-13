self: super:
{
  dix = super.dix or { } //
    {
      OrbStack = super.callPackage (import ./packages/darwin/OrbStack.app) { };
      Splice = super.callPackage (import ./packages/darwin/Splice.app) { };
    };
}
