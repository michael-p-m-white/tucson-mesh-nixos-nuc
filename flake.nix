{
  inputs = {
    nixpkgs-stable = {
      type  = "github";
      owner = "NixOS";
      repo  = "nixpkgs";
      ref   = "nixos-23.11";
    };

    nixpkgs-unstable = {
      type  = "github";
      owner = "NixOS";
      repo  = "nixpkgs";
      ref   = "nixos-unstable";
    };

    agenix = {
      type  = "github";
      owner = "ryantm";
      repo  = "agenix";
      ref   = "main";
      inputs = {
        nixpkgs.follows = "nixpkgs-stable";
        systems.follows = "systems";
      };
    };

    systems = {
      type  = "github";
      owner = "nix-systems";
      repo  = "default";
      ref   = "main";
    };
  };

  outputs = { self
            , nixpkgs-stable
            , nixpkgs-unstable
            , agenix
            , systems
            , ... 
            }@inputs:
              let
                eachSystem = nixpkgs-stable.lib.genAttrs (import systems);
              in
                {
                  nixosConfigurations =
                    let
                      system = "x86_64-linux";
                    in
                      {
                        nixos = nixpkgs-stable.lib.nixosSystem {
                          inherit system;
                          specialArgs = { inherit inputs; };
                          modules =
                            [ ./configuration.nix
                              agenix.outputs.nixosModules.age
                            ];
                        };
                      };

                  packages = eachSystem (system: {
                    agenix = agenix.outputs.packages."${system}".agenix;
                  });                  
                };
}
