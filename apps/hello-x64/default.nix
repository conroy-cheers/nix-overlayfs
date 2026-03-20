{
  pkgsCross,
  runCommand,
  overlayfsLib,
  modules,
}:
let
  pname = "hello-x64";
  version = "1.0.0";
  mingwCc = pkgsCross.mingwW64.stdenv.cc;

  installPath = "drive_c/Program Files/HelloX64";

  basePackage = runCommand "${pname}-${version}" {
    inherit pname version;
    nativeBuildInputs = [ mingwCc ];
  } ''
    mkdir -p "$out/${installPath}"

    x86_64-w64-mingw32-gcc \
      -O2 \
      -s \
      -static \
      -static-libgcc \
      -o "$out/${installPath}/hello-x64.exe" \
      ${./hello-x64.c}
  '';
in
overlayfsLib.composeWindowsLayers {
  inherit (modules) runtime;
  packageName = "HelloX64/HelloX64";
  baseLayer = {
    inherit basePackage;
    overlayDependencies = [ ];
    runtimeEnvVars = { };
  };
  executableName = "hello-x64";
  executablePath = "${modules.runtime.programFilesPath}/HelloX64/hello-x64.exe";
  workingDirectory = installPath;
}
