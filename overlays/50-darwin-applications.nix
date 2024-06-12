self: super:
{
  dix = super.dix or { } //
    {
      Arc = super.callPackage (import ./packages/darwin/Arc.app) { };
      Bitwarden = super.callPackage (import ./packages/darwin/Bitwarden.app) { };
      Discord = super.callPackage (import ./packages/darwin/Discord.app) { };
      Firefox = super.callPackage (import ./packages/darwin/Firefox.app) { };
      OrbStack = super.callPackage (import ./packages/darwin/OrbStack.app) { };
      Obsidian = super.callPackage (import ./packages/darwin/Obsidian.app) { };
      Rectangle = super.callPackage (import ./packages/darwin/Rectangle.app) { };
      Zed = super.callPackage (import ./packages/darwin/Zed.app) { };
      Zotero = super.callPackage (import ./packages/darwin/Zotero.app) { };
    };
}
