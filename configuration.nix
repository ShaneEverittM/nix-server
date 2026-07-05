# NixOS configuration for a lil' home server.
{ pkgs, inputs, ... }:

let
  sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwRBMnr95gqzkvJHmNDCprKK2QcV2vNQVS6mAsGzcz3";
  email = "mail@semurphy.com";
in
{
  imports = [
    # Grab the generated config from the installer, mostly just kernel modules and filesystem mounts.
    ./hardware-configuration.nix

    # Run home-manager as part of the system build, so `nh os switch` applies
    # user-level config too — no separate home-manager CLI to invoke.
    inputs.home-manager.nixosModules.home-manager
  ];

  # The version this configration is authored against.
  system.stateVersion = "26.05";

  # Use Sytemd as the boot manager.
  boot.loader.systemd-boot.enable = true;

  # Enable modifying EFI variables (rollback).
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable running non-nix-built binaries (Zed remote SSH server).
  programs.nix-ld.enable = true;

  # Enable known-stable experimental features.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Use the `nh` CLI for managing build/switch.
  programs.nh = {
    enable = true;
    flake = "/home/shane/.config/nix";
  };

  # Set the hostname.
  networking.hostName = "nixos";

  # Configure wireless to autoconnect, see README.md for PSK notes.
  networking.wireless = {
    enable = true;
    secretsFile = "/etc/wpa_supplicant/wireless.conf";
    networks."Marconi".pskRaw = "ext:psk_Marconi";
  };

  # Enable hostname publishing, so that `ssh <user>@<hostname>` works.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Gotta have a time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # User-level config, borrowed piecemeal from the personal flake.
  home-manager = {
    # Use the system's nixpkgs (and its allowUnfree etc.) instead of evaluating
    # a private copy per user, and install user packages via the system profile.
    useGlobalPkgs = true;
    useUserPackages = true;

    users."shane" = {
      imports = [
        # Git behavior (aliases, diff-so-fancy pager, LFS filters, colors).
        # Identity stays out of the shared module and is injected below via
        # its publicHome.git options. Replaces the system-wide programs.git
        # we used to configure here; signing setup is unchanged.
        inputs.personal.homeModules.git
      ];

      # The git module expects these on PATH (see its header comment).
      home.packages = with pkgs; [
        git-lfs
        diff-so-fancy
      ];

      publicHome.git = {
        userName = "Shane Murphy";
        userEmail = email;
        signingKey = sshPublicKey;
      };

      # The shared module signs commits; also sign tags like we did before.
      programs.git.settings.tag.gpgsign = true;

      # Home-manager's compatibility anchor, same idea as system.stateVersion.
      home.stateVersion = "26.05";
    };
  };

  # Set up the user account.
  users.users."shane" = {
    isNormalUser = true;
    description = "Shane Murphy";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      sshPublicKey
    ];
  };

  # Allow unfree packages, nothing currently but we aren't *that* much of a purist.
  nixpkgs.config.allowUnfree = true;

  # System-wide packages.
  environment.systemPackages = with pkgs; [
    # For bootsrapping edits before remote editors work.
    neovim
    # Nix language server (used by Zed over remote SSH).
    nixd
    # Nix formatter (`nixfmt`) (again by Zed over remote SSH).
    nixfmt
    # System info at a glance.
    fastfetch
  ];

  # Enable OpenSSH daemon.
  services.openssh.enable = true;

  # Configure the system to not sleep on lid closed, server-style.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  # Compressed on-filesystem swap.
  zramSwap.enable = true;
}
