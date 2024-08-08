self: super: {
  dix = super.recurseIntoAttrs (super.dix or {});

  zed-editor =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.zed-editor;

  julia_19 =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.julia_19;

  cudaPackages = super.recurseIntoAttrs (super.cudaPackages
    // {
      cudnn =
        if super.stdenv.isDarwin
        then null
        else
          (
            super.cudaPackages.cudnn.overrideAttrs (oa: {
              postFixup =
                oa.postFixup
                + ''
                  rm $out/LICENSE
                '';
            })
          );
      tensorrt =
        if super.stdenv.isDarwin
        then null
        else super.cudaPackages.tensorrt;
    });

  cudatoolkit =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.cudatoolkit;
}
