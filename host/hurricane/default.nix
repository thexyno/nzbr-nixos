{ config, lib, pkgs, modulesPath, ... }:
{
  networking.hostName = "hurricane";

  nzbr = {
    patterns = [ "common" "wsl" "development" "hapra" ];
    pattern.development.guiTools = true;

    service = {
      syncthing.enable = true;
    };

    program = {
      latex.enable = true;
    };
  };

}