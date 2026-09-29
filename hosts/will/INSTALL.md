# Installing `will` (unknown hardware)

Result: UEFI + systemd-boot, LUKS2 full-disk encryption, btrfs subvolumes
`@` → `/`, `@home` → `/home`, `@nix` → `/nix` (Snapper snapshots `/` and `/home`),
the dusky Hyprland desktop, and the CachyOS kernel from its binary cache.
The disk passphrase and Will's login password are set to the same value.

`DISK` below is the target disk (`lsblk`), e.g. `/dev/nvme0n1` or `/dev/sda`.
**Everything on it is erased.**

## 0. Boot the installer

Boot the NixOS 26.05 minimal ISO (UEFI mode), get online (ethernet; for
wifi see "Networking in the installer" in the NixOS manual), then `sudo -i`. The repo is public: no keys or accounts needed.

## 1. Partition, encrypt, format

```sh
DISK=/dev/nvme0n1
parted -s "$DISK" -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB set 1 esp on \
  mkpart cryptroot 1GiB 100%
udevadm settle

mkfs.fat -F32 -n BOOT /dev/disk/by-partlabel/ESP

# Choose the passphrase now: it will also be Will's login password.
cryptsetup luksFormat --type luks2 /dev/disk/by-partlabel/cryptroot
cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot

mkfs.btrfs -L nixos /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

o=compress=zstd,noatime
mount -o subvol=@,$o     /dev/mapper/cryptroot /mnt
mkdir -p /mnt/home /mnt/nix /mnt/boot
mount -o subvol=@home,$o /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,$o  /dev/mapper/cryptroot /mnt/nix
mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot

# Snapper keeps snapshots in a .snapshots subvolume inside each config's subvolume.
btrfs subvolume create /mnt/.snapshots
btrfs subvolume create /mnt/home/.snapshots
```

## 2. Get the config and this machine's hardware file

```sh
nix-shell -p git --run \
  'git clone https://github.com/chowe99/dusky-nix.git /mnt/home/will/dusky-nix'
cd /mnt/home/will/dusky-nix

nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/will/hardware-configuration.nix
```

Check the generated file has the LUKS device
(`boot.initrd.luks.devices."cryptroot"`) and the three btrfs mounts with
`subvol=@`, `subvol=@home`, `subvol=@nix`. Add `"compress=zstd" "noatime"` to
their `options` if it left them out. Send this file to the repo owner to commit
(step 5).

## 3. Install

The `--option` lines let the installer download the prebuilt CachyOS kernel
instead of compiling it (the installed system has this cache configured itself).

```sh
nixos-install --no-root-passwd --flake /mnt/home/will/dusky-nix#will \
  --option extra-experimental-features 'nix-command flakes' \
  --option extra-substituters https://attic.xuyh0120.win/lantian \
  --option extra-trusted-public-keys lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=
```

## 4. Password, reboot

No password is in the repo (not even a hash: a hash of the disk passphrase in
git history could be cracked offline). Until this step the account is locked.
Enter **the same passphrase as the disk**:

```sh
nixos-enter --root /mnt -c 'passwd will'
nixos-enter --root /mnt -c 'chown -R will:users /home/will'
reboot
```

Boot: Plymouth asks for the disk passphrase, then tuigreet asks for Will's
password (same one) and starts Hyprland. First login fetches a wallpaper and
generates the colour theme (needs network).

Root has no password; `sudo` uses Will's password.

The disk passphrase and the login password are independent from here on:
changing one does not change the other. To change both:

```sh
sudo cryptsetup luksChangeKey /dev/disk/by-partlabel/cryptroot
passwd
```

## 5. Updates

Once the owner has committed Will's hardware file, drop the local copy so
`git pull` fast-forwards:

```sh
git -C ~/dusky-nix checkout -- hosts/will/hardware-configuration.nix
```

Then, whenever the owner pushes (the `update-system` alias does both):

```sh
git -C ~/dusky-nix pull --ff-only
nixos-rebuild switch --sudo --flake ~/dusky-nix#will
```

Or without a clone (only once the hardware file is committed):
`sudo nixos-rebuild switch --flake github:chowe99/dusky-nix#will`.

Rollback: pick an older generation in the systemd-boot menu, or
`sudo snapper -c home list` / `snapper -c root list` for file-level restores.
