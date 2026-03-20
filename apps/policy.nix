{
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  preferredNamespaceByApp =
    {
      aarch64-linux = {
        notepad-plus-plus = "x64Fex";
      };
      x86_64-linux = { };
    }
    .${system}
    or { };
}
