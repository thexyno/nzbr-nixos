{
  description = "my very own special snowflake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base = {
      url = "github:nix-basement/nix-basement";
      # url = "/home/nzbr/devsaur/nixos-base";
      # url = "/storage/nzbr/devsaur/nixos-base";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    naersk = {
      # rust package builder
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nirgenx = {
      url = "github:nzbr/nirgenx";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rnix-lsp = {
      url = "github:nix-community/rnix-lsp";
      inputs.naersk.follows = "naersk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
    xyno-experiments = {
      url = "github:thexyno/x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:nzbr/dotfiles";
      # TODO: submodules = true; (once that is supported)
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    razer-nari = {
      flake = false;
      url = "github:imustafin/razer-nari-pulseaudio-profile";
    };
    wsld = {
      flake = false;
      url = "github:nbdd0121/wsld";
    };
    cert-manager-desec = {
      flake = false;
      url = "github:kmorning/cert-manager-webhook-desec";
    };
    # ceph-csi = {
    #   flake = false;
    #   url = "github:ceph/ceph-csi/release-v3.4";
    # };
  };

  outputs =
    inputs @ { self
    , flake-utils
    , nixpkgs
    , ...
    }:
    let
      baseLib = import ./lib/base.nix { lib = nixpkgs.lib; };
      lib = with nixpkgs.lib; foldl recursiveUpdate nixpkgs.lib ((map (x: import x { inherit lib; }) (baseLib.findModules ".nix" ./lib)) ++ [ inputs.nirgenx.lib ]);
    in
    with builtins; with lib; {
      inherit lib;

      nixosModules =
        let
          modulesPath = "${self}/module";
        in
        listToAttrs (
          map
            (file:
              nameValuePair'
                (removePrefix "${modulesPath}/" file)
                (import file)
            )
            (lib.findModules ".nix" modulesPath)
        );

      nixosConfigurations =
        let
          allConfigs = system:
            let
              mkDefaultSystem = hostName: mkSystem hostName [ ];
              mkSystem = hostName: extraModules: (nixosSystem {
                inherit system;
                specialArgs = {
                  inherit lib inputs system hostName extraModules;
                };
                modules =
                  [
                    {
                      imports = mapAttrsToList
                        (name: type: "${self}/core/${name}")
                        (readDir "${self}/core");

                      nzbr.flake = {
                        root = "${inputs.self}";
                        assets = "${inputs.self}/asset";
                        host = "${inputs.self}/host/${hostName}";
                      };
                    }
                  ];
              });
            in
            (listToAttrs (map
              (hostName:
                lib.nameValuePair
                  hostName
                  (
                    (
                      mkDefaultSystem hostName
                    ) // (
                      mapAttrs'
                        (n: v: nameValuePair' (removeSuffix ".nix" n) (mkSystem hostName [ "${self}/host/${hostName}/${n}" ]))
                        (
                          filterAttrs
                            (n: v: (v == "regular") && (hasSuffix ".nix" n) && (n != "default.nix"))
                            (readDir "${self}/host/${hostName}")
                        )
                    )
                  )
              )
              (mapAttrsToList (name: type: name) (readDir "${self}/host"))
            ));
        in
        mapAttrs
          (n: v: (allConfigs v.config.nzbr.system).${n})
          (allConfigs "x86_64-linux");
    } //
    (flake-utils.lib.eachSystem
      lib.systems.flakeExposed
      (system:
      let
        pkgs = (import "${inputs.nixpkgs}" { inherit system; });
        naersk = pkgs.callPackage "${inputs.naersk}" { };
        scripts = (
          # legacy scripts.nix
          mapAttrs (name: script: pkgs.writeShellScriptBin name script) ((import ./scripts.nix) { inherit lib self; pkgs = (pkgs // self.packages.${system}); })
        ) // (
          # collect from script directory
          listToAttrs (
            map
              (file: rec {
                name = unsafeDiscardStringContext (replaceStrings [ "/" ] [ "-" ] (removePrefix "${self}/script/" file)); # this is safe, actually
                value = pkgs.substituteAll {
                  inherit name;
                  src = file;
                  dir = "bin";
                  isExecutable = true;

                  python3 = pkgs.python3.withPackages (pypi: with pypi; [
                    pygraphviz
                  ]);

                  # packages that are available to the scripts
                  inherit (pkgs)
                    bash
                    gnused
                    jq
                    nixFlakes
                    openssh
                    powershell
                    rage
                    ;
                  wireguard = pkgs.wireguard-tools;
                  nixpkgs = toString inputs.nixpkgs;
                };
              })
              (findModules "" "${self}/script")
          )
        );
      in
      (with builtins; with nixpkgs; with lib; rec {

        devShell = pkgs.mkShell {
          buildInputs =
            let
              ifAvailable = collection: package: (orElse collection system { ${package} = [ ]; }).${package};
            in
            with pkgs; (flatten [
              (ifAvailable inputs.agenix.packages "agenix")
              graphviz
              morph
              nixpkgs-fmt
              rage
              (ifAvailable inputs.nirgenx.packages "helm-update")
              (ifAvailable inputs.nirgenx.packages "yaml2nix")
            ])
            ++
            mapAttrsToList
              (name: drv: pkgs.writeShellScriptBin name "set -ex\nexec ${pkgs.nixUnstable}/bin/nix run .#${name} \"$@\"")
              scripts;
        };

        checks = {
          nixpkgs-fmt = pkgs.runCommand "check-nixpkgs-fmt" { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; } ''
            nixpkgs-fmt --check ${./.}
            touch $out
          '';
        };

        apps = mapAttrs'
          (name: value:
            nameValuePair'
              name
              (flake-utils.lib.mkApp
                {
                  inherit name;
                  drv = value;
                }
              )
          )
          scripts // packages;

        packages =
          filterAttrs
            (name: pkg: (elem system (orElse pkg.meta "platforms" [ system ])))
            (
              loadPackages pkgs { inherit inputs naersk; } ".pkg.nix" ./package # import all packages from pkg directory
            );

      }))
    );
}
