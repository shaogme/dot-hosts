{ config, lib, ... }:

{
  imports =
    let
      dir = /etc/nixos-extra/services;
    in
      if builtins.pathExists dir then
        let
          files = builtins.readDir dir;
          nixFiles = builtins.filter 
            (name: (files.${name} == "regular" || files.${name} == "symlink") && lib.hasSuffix ".nix" name) 
            (builtins.attrNames files);
        in
          map (name: dir + "/${name}") nixFiles
      else
        [];
}
