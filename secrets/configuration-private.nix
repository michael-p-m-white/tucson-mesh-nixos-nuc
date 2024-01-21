{ config, ...}:
{
  # Configure authorized SSH keys for users, so they can login without passwords
  users.users.josh.openssh.authorizedKeys.keys = [
    # An example public key, copied from the README of agenix (https://github.com/ryantm/agenix#tutorial)
    # In practice, this should match a private key for the user which is already present on the target machine.
	  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzxQgondgEYcLpcPdJLrTdNgZ2gznOHCAxMdaceTUT1"
  ];

  # agenix manages files which are encrypted with age.
  # A secret of the form age.secrets.<name>.file will be decrypted on the target machine as part of system activation.
  # The path of the decrypted file on the target machine is available in config.age.secrets.<name>.path.
  age.secrets.mesh-wg-private-key.file = ./mesh-wg-private-key.age;
  age.secrets.mesh-wg-psk.file         = ./mesh-wg-psk.age;


  # agenix uses private keys present on the target machine to decrypt secrets.
  # By default, these are the keys in config.services.openssh.hostKeys of type "rsa" or "ed25519".
  # If this default is not workable, set the key files to use by uncommenting and setting age.identityPaths appropriately.
  # 
  # age.identityPaths = [
  #   # Add paths to private keys to use for decryption here.
  # ];

  networking.wireguard.interfaces = {
    mesh-wg = {
      privateKeyFile = config.age.secrets.mesh-wg-private-key.path;

      peers = [{
        presharedKeyFile = config.age.secrets.mesh-wg-psk.path;

        # Additional settings necessary to make the wireguard network actually work should go here.
        persistentKeepalive = 25;

        # All of the below information is placeholder, for demonstration purposes only (as even nixos-rebuild dry-build
        # complains if it is missing).
        publicKey = "ofHuZYeylrz4zGJ6XAMVgX8V1qb5R7gLb0ThN74/MeI6";
        endpoint = "255.255.255.255:65535";
        allowedIPs = ["10.0.0.0/32" "10.0.0.0/16" "10.0.0.0/16"];
      }];
    };
  };
}
