{
  description = "My dusky desktop";

  inputs.dusky-nix.url = "github:chowe99/dusky-nix";

  outputs = {dusky-nix, ...}: {
    # Rename "my-machine" / "me" to your hostname and username (the username
    # defaults to the hostname; pass `username = "..."` to change it).
    nixosConfigurations.my-machine = dusky-nix.lib.mkSystem {
      hostname = "my-machine";
      username = "me";
      hostConfig = ./hosts/my-machine/configuration.nix;
      homeConfig = ./users/me/home.nix;
      specialArgs = {inherit (dusky-nix) inputs;};
    };
  };
}
