# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "nomodeset" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.efiInstallAsRemovable = true;

  fileSystems."/" =
    { device = "rpool/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-label/swap"; }
    ];

  hardware.video.hidpi.enable = lib.mkDefault true;

  networking.hostId = "d0dce459";
  networking.hostName = "macofborg1";
  nixpkgs.config.allowUnfree = true;
}
