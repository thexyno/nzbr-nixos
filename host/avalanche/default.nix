{ config, lib, pkgs, modulesPath, ... }:
let
  root = config.nzbr.flake.root;
in
{
  networking = {
    hostName = "avalanche";
    hostId = "24071395";
  };

  nzbr = {
    patterns = [ "common" "server" ];

    boot = {
      grub.enable = true;
      remoteUnlock = {
        luks = false;
        zfs = [ "zroot" ];
      };
    };

    network = {
      wireguard = {
        enable = true;
        ip = "10.42.0.4";
      };
    };

    service = {
      k3s.enable = true;
      restic = {
        enable = true;
        remote = "jotta-archive";
        include = [
          "zroot/etc"
          "zroot/home"
          "zroot/root"
          "zroot/srv"
          "zroot/storage"
        ];
        healthcheck = {
          backup = "https://hc-ping.com/a4db4963-0a73-4aeb-8207-f884341ba04d";
          prune = "https://hc-ping.com/be3cdc9a-3eb4-4f85-b8ad-c51dc361f9e7";
        };
        pools = [
          {
            name = "zroot";
            subvols = [
              { name = "nix-store"; mountpoint = "/nix/store"; }
              { name = "kubernetes"; mountpoint = "/storage/kubernetes"; }
            ];
          }
        ];
      };
    };
  };

  boot = {
    loader.grub.device = "/dev/sda";
    loader.grub.configurationLimit = 1;

    initrd = {
      availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"

        "virtio_net" # Early boot network
      ];
      kernelModules = [ ];
      supportedFilesystems = [ "zfs" ];
    };
    kernelModules = [ ];
    supportedFilesystems = [ "zfs" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "zroot";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/F3BE-8A41";
      fsType = "vfat";
    };
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=4G" ];
    };
    "/nix/store" = {
      device = "zroot/nix-store";
      fsType = "zfs";
    };

    "/storage/kubernetes" = {
      device = "zroot/kubernetes";
      fsType = "zfs";
    };
  }
  //
  lib.mapAttrs'
    (to: from:
      {
        name = to;
        value = {
          device = from;
          options = [ "bind" ];
        };
      }
    )
    {
      "/var/lib/rancher/k3s/storage" = "/storage/kubernetes/local-path";
      "/var/lib/longhorn" = "/storage/kubernetes/longhorn";
      "/var/lib/rook" = "/storage/kubernetes/rook";
      "/var/lib/etcd" = "/storage/kubernetes/etcd";
    };

  swapDevices = [
    {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0-part3";
      randomEncryption.enable = true;
    }
  ];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  services.qemuGuest.enable = true;

  networking = {
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    interfaces.ens3 = {
      useDHCP = true;
      ipv6 = {
        addresses = [{
          address = "2a03:4000:53:7a::";
          prefixLength = 64;
        }];
        routes = [{
          address = "::";
          prefixLength = 0;
          via = "fe80::1";
        }];
      };
    };
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [
      "10.42.0.4/24"
      "fd42:42::88fc:d9ff:fe45:ead8/64"
    ];
    peers = [
      {
        # storm
        publicKey = (lib.fileContents config.nzbr.foreignAssets.storm."wireguard/public.key");
        endpoint = "storm.nzbr.de:51820";
        allowedIPs = [
          "10.42.0.0/26"
          "fd42:42::/32"
        ];
      }
      {
        # earthquake
        publicKey = (lib.fileContents config.nzbr.foreignAssets.earthquake."wireguard/public.key");
        endpoint = "earthquake.nzbr.de:51820";
        allowedIPs = [
          "10.42.0.2/32"
          "fd42:42::7a24:afff:febc:c07/128"
          "10.0.0.0/16" # LAN
        ];
      }
    ];
  };
}