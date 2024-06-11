{ installDmg, fetchurl }:
installDmg rec {
  name = "Obsidian";
  version = "1.6.3";
  sourceRoot = "${name}.app";
  src = fetchurl {
    url = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/${name}-${version}-universal.dmg";
    hash = "sha256-o5ELpG82mJgcd9Pil6A99BPK6Hoa0OKJJkYpyfGJR9I=";
  };
  description = "Sharpen your thinking.";
  homepage = "https://obsidian.md/";
}
