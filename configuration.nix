# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  unstablePkgs = import ( fetchTarball https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz ) { config = config.nixpkgs.config; };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./ups.nix
      ./mapgen.nix
      ./caddy.nix
      ./restic.nix
      ./secrets/configuration-private.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # tailscale subnet routers need to be able to forward 
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  networking.hostName = "nixos-dell"; # Define your hostname.
  # ignore wpa_supplicant because we'll be using NetworkManager to configure wireless networking
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "America/Phoenix";

  networking = {
    networkmanager.enable = true;
  };
  
  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Define user accounts. Don't forget to set a password with ‘passwd’.
  users.users.josh = {
    isNormalUser = true;
    home = "/home/josh";
    description = "josh";
    extraGroups = [ "wheel" "networkmanager" "docker" ]; # Enable 'sudo', ability to configure network, and docker
    # hashed passwords and authorized keys set in ./configuration-private.nix
  };

  # Disable mutable users
  users.mutableUsers = false;

  # Only wheel (sudo) users can do nix sry
  nix.settings.allowed-users = [ "@wheel" ];
  security.sudo.execWheelOnly = true;

  # Packages installed in system profile
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    firefox
    tmux
    mosh
    stow
    wireguard-tools
    htop
    podman-compose
    docker-compose
    usbutils
    qrencode
    envsubst
    quickemu
    sshpass
    age
    unstablePkgs.helix
    unstablePkgs.tailscale
  ];

  # Disable sleep
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Enable X11 + gnome + xfce.
  services.xserver = {
    enable = true;
    displayManager = {
      gdm.enable = true;
    };
    desktopManager = {
      gnome.enable = true;
      xfce.enable = true;
    };
  };
    
  # Enable xrdp with xfce as the DE because gnome is being a pain in the ass
  services.xrdp = {
    enable = true;
    defaultWindowManager = "xfce4-session";
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    # From Xe Iaso
    # except the agent forwarding
    extraConfig = ''
      AuthenticationMethods publickey
      AllowStreamLocalForwarding no
      AllowAgentForwarding yes
      AllowTcpForwarding yes
      X11Forwarding no
    '';
  };

  networking.nat.enable = true;
  # Death to Wi-Fi, long live Ethernet
  networking.nat.externalInterface = "enp4s0";
  networking.nat.internalInterfaces = [ "mesh-wg" ];
  # Configure the firewall
  networking.firewall = {
    enable = true;
    # It would be cool to not do this, but there are lots of edge cases
    # And if you're successfully sending packets in on either of these interfaces, you're authenticated already anyway
    trustedInterfaces = [ "tailscale0" "mesh-wg" ];
    allowedTCPPorts = [ 
      # ssh
      22 
      # xrdp
      3389
      # mesh services/caddy reverse proxy
      # applies filtering based on IP for certain routes anyway
      80
    ];
    allowedUDPPortRanges = [
      # wireguard
      { from = 51820; to = 51820; }
      # mosh server
      { from = 60000; to = 61000; }
      # tailscale
      { from = config.services.tailscale.port; to = config.services.tailscale.port; }
    ];
    # "warning: Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups. Consider setting `networking.firewall.checkReversePath` = 'loose'"
    checkReversePath = "loose";
  };
  
  # Enable and configure tailscale with a oneshot systemd unit
  nixpkgs.overlays = [(final: prev: {
    tailscale = unstablePkgs.tailscale;
  })];
  services.tailscale.enable = true;
  # oneshot systemd unit defined in ./configuration-private.nix

  networking.wireguard.interfaces = {
    mesh-wg = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.100.0.1/24" ];

      # The port that WireGuard listens to. Must be accessible by the client + synchronized with firewall allowedUDPPorts
      listenPort = 51820;

      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o enp0s29u1u1 -j MASQUERADE
      '';

      # This undoes the above command
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o enp0s29u1u1 -j MASQUERADE
      '';

      # private key file and peers defined in ./configuration-private.nix
    };
  };
  
  # Virtualization
  virtualisation = {
    podman = {
      enable = true;
    };
    docker = {
      enable = true;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  # don't do auto upgrades
  system.autoUpgrade.enable = false;
  system.autoUpgrade.allowReboot = false;

  # periodically collect garbage
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # and do automatic store optimization
  nix.settings.auto-optimise-store = true;
}

