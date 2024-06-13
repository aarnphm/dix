{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.awscli = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''awscli configuration'';
    };
  };

  config = mkIf config.awscli.enable {
    programs = {
      awscli = {
        enable = true;
        settings = {
          default = {
            region = "us-east-1";
            output = "json";
          };
          bentoml-prod = {
            region = "us-west-1";
            output = "json";
          };
        };
        credentials = {
          default = {
            "credential_process" = "${lib.getExe pkgs.dix.aws-credentials} default";
          };
          bentoml-prod = {
            "credential_process" = "${lib.getExe pkgs.dix.aws-credentials} bentoml_prod";
          };
        };
      };
    };
  };
}
