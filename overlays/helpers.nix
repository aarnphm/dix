{
  checkArm = super: builtins.match "aarch64-.*" super.stdenv.hostPlatform.system != null;
}
