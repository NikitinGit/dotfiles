{ lib }:
let
  inherit (builtins) readDir;
  inherit (lib)
    attrNames
    filterAttrs
    hasAttr
    hasSuffix
    mapAttrs
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  # Import a single module file
  importModule = path: filename: import (path + "/${filename}");

  # Recursively collect modules from a directory
  # Returns nested attrset: { bat = <module>; languages = { kotlin = <module>; }; }
  collectModules =
    path:
    let
      contents = readDir path;

      nixFiles = filterAttrs (
        name: type: type == "regular" && hasSuffix ".nix" name && name != "default.nix"
      ) contents;

      subDirs = filterAttrs (name: type: type == "directory") contents;

      # Import .nix files as modules
      fileModules = mapAttrs' (
        filename: _: nameValuePair (removeSuffix ".nix" filename) (importModule path filename)
      ) nixFiles;

      # Recursively process subdirectories
      dirModules = mapAttrs (dirname: _: collectModules (path + "/${dirname}")) subDirs;
    in
    fileModules // dirModules;

  # Extract specific module type (homeModule, nixosModule) from collected modules
  # Flattens nested structure for easier use
  extractModuleType =
    type: modules:
    let
      extract =
        prefix: mods:
        lib.concatMapAttrs (
          name: value:
          if hasAttr type value then
            { ${if prefix == "" then name else "${prefix}/${name}"} = value.${type}; }
          else if builtins.isAttrs value then
            extract (if prefix == "" then name else "${prefix}/${name}") value
          else
            { }
        ) mods;
    in
    extract "" modules;

  modules = collectModules ./modules;

in
{
  inherit modules;

  # Helper to get list of module attrs for a specific type
  getHomeModules =
    moduleList: map (m: m.homeModule) (builtins.filter (hasAttr "homeModule") moduleList);

  getNixosModules =
    moduleList: map (m: m.nixosModule) (builtins.filter (hasAttr "nixosModule") moduleList);
}
