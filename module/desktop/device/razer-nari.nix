let
  repo = builtins.fetchGit {
    url = "https://github.com/imustafin/razer-nari-pulseaudio-profile.git";
    ref = "master";
  };
in
{ config, lib, pkgs, modulesPath, ... }:
{
  services.udev.extraRules = builtins.readFile "${repo}/91-pulseaudio-razer-nari.rules";

  hardware.pulseaudio = {
    package = pkgs.pulseaudioRazerNari;
  };

  nixpkgs.overlays = [
    (self: super: {
      pulseaudioRazerNari = super.pulseaudioFull.overrideAttrs (oldAttrs: rec {
        preFixup = oldAttrs.preFixup + ''
          mkdir -p $out/share/pulseaudio/alsa-mixer/{profile-sets,paths}
          cp ${repo}/razer-nari-input.conf $out/share/pulseaudio/alsa-mixer/paths/
          cp ${repo}/razer-nari-output-{game,chat}.conf $out/share/pulseaudio/alsa-mixer/paths/
          cp ${repo}/razer-nari-usb-audio.conf $out/share/pulseaudio/alsa-mixer/profile-sets/
        '';
      });
    })
  ];
}