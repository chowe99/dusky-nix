{ config, pkgs, lib, ... }:

{
  # Libvirt + QEMU
  virtualisation.libvirtd = {
    enable = lib.mkDefault false;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      ovmf.enable = true;
      ovmf.packages = [ pkgs.OVMFFull.fd ];
    };
  };

  programs.virt-manager.enable = lib.mkDefault false;

  # Add user to libvirtd group when enabled
  users.users.${config.dusky.user.name}.extraGroups =
    lib.optionals config.virtualisation.libvirtd.enable [ "libvirtd" "kvm" ];
}
