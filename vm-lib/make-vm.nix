# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie

{ config ? import ../../../nix/eval-config.nix {}

# Paths that are present in the base image that will start this VM's
# run script, and don't so need to be duplicated in the extension
# partition's store.
, basePaths ? builtins.toFile "null" ""
}:

config.pkgs.pkgsStatic.callPackage (

{ lib, runCommand, writeReferencesToFile, e2fsprogs, tar2ext4 }:

{ name, run, providers ? {}, wayland ? false }:

let
  inherit (lib)
    any attrValues concatLists concatStrings hasInfix mapAttrsToList;
in

assert !(any (hasInfix "\n") (concatLists (attrValues providers)));

runCommand "spectrum-vm" {
  nativeBuildInputs = [ e2fsprogs tar2ext4 ];

  inherit wayland;

  providerDirs = concatStrings (concatLists
    (mapAttrsToList (kind: map (vm: "${kind}/${vm}\n")) providers));
  passAsFile = [ "providerDirs" ];
} ''
  mkdir -p "$out"/{blk,providers}

  mkdir root
  cd root
  ln -s ${run} run
  ln -s ${config.pkgs.mesa.drivers}/lib
  comm -23 <(sort -u ${writeReferencesToFile run} ${writeReferencesToFile config.pkgs.mesa.drivers}) \
      <(sort ${writeReferencesToFile basePaths}) |
      tar -cf ../run.tar --verbatim-files-from -T - *
  tar2ext4 -i ../run.tar -o "$out/blk/run.img"
  e2label "$out/blk/run.img" ext

  pushd "$out/providers"
  xargs -rd '\n' dirname -- < "$providerDirsPath" | xargs -rd '\n' mkdir -p --
  xargs -rd '\n' touch -- < "$providerDirsPath"
  popd

  if [ -n "$wayland" ]; then
      touch "$out/wayland"
  fi

  ln -s /usr/img/appvm/blk/root.img "$out/blk"
  ln -s /usr/img/appvm/vmlinux "$out"
''
) {}
