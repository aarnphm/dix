self: super:
{
  dix = super.dix or { } //
    {
      OrbStack = super.callPackage (import ./packages/darwin/OrbStack.app) { };
      Rectangle = super.callPackage (import ./packages/darwin/Rectangle.app) { };
      Discord = super.callPackage (import ./packages/darwin/Discord.app) { };
      Bitwarden = super.callPackage (import ./packages/darwin/Bitwarden.app) { };
      Zed = super.callPackage (import ./packages/darwin/Zed.app) { };
      Obsidian = super.callPackage (import ./packages/darwin/Obsidian.app) { };
    };
}

