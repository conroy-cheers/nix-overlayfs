{
  fetchurl,
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "msxml";
  version = "6.0";
  src = fetchurl {
    url = "https://download.microsoft.com/download/2/7/7/277681BE-4048-4A58-ABBA-259C465B1699/msxml6-KB2957482-enu-amd64.exe";
    hash = "sha256-JgzYcIUf/DxtELcWkfE04g2NA6wmBzuzaVHqy3qoWJc=";
  };
  packageName = "msxml6";
  silentFlags = "/quiet /norestart";
}
