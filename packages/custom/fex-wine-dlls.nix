{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  python3,
  git,
  fex,
  fmt,
  llvmMingwArm64ec,
  range-v3,
  xxHash,
}:
stdenv.mkDerivation {
  pname = "fex-wine-dlls";
  version = fex.version;
  src = fex.src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    python3
    git
    fmt.dev
    range-v3
  ];

  buildInputs = [ llvmMingwArm64ec ];

  configurePhase = ''
    runHook preConfigure
    export PATH=${llvmMingwArm64ec}/bin:$PATH
    export CMAKE_PREFIX_PATH=${fmt.dev}:${range-v3}${"\${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"}
    arm64ecBuiltinsArchive="$(echo ${llvmMingwArm64ec}/lib/clang/*/lib/windows/libclang_rt.builtins-aarch64.a)"
    mkdir -p ./arm64ec-builtins
    mapfile -t arm64ecBuiltinObjects < <(
      llvm-ar t "$arm64ecBuiltinsArchive" \
        | sort -u \
        | grep -E '(^chkstk\.S\.obj$|^clear_cache\.c\.obj$|ti)'
    )
    (
      cd ./arm64ec-builtins
      llvm-ar x "$arm64ecBuiltinsArchive" "''${arm64ecBuiltinObjects[@]}"
    )
    arm64ecBuiltins="$(printf '%s ' "$PWD"/arm64ec-builtins/*.obj)"
    arm64ecBuiltins="''${arm64ecBuiltins% }"
    rm -rf External/xxhash
    cp -R --no-preserve=mode ${xxHash.src} External/xxhash
    while IFS= read -r cmakeFile; do
      substituteInPlace "$cmakeFile" --replace-warn 'fmt::fmt' 'fmt::fmt-header-only'
    done < <(find . -name CMakeLists.txt -print)
    cp Data/CMake/toolchain_mingw.cmake ./toolchain_mingw_arm64ec.cmake
    substituteInPlace ./toolchain_mingw_arm64ec.cmake \
      --replace 'set(CMAKE_C_STANDARD_LIBRARIES "" CACHE STRING "" FORCE)' \
                "set(CMAKE_C_STANDARD_LIBRARIES \"$arm64ecBuiltins\" CACHE STRING \"\" FORCE)" \
      --replace 'set(CMAKE_CXX_STANDARD_LIBRARIES "" CACHE STRING "" FORCE)' \
                "set(CMAKE_CXX_STANDARD_LIBRARIES \"$arm64ecBuiltins\" CACHE STRING \"\" FORCE)" \
      --replace 'set(CMAKE_STANDARD_LIBRARIES "" CACHE STRING "" FORCE)' \
                "set(CMAKE_STANDARD_LIBRARIES \"$arm64ecBuiltins\" CACHE STRING \"\" FORCE)"

    cmake -S . -B build_arm64ec \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=/ \
      -DENABLE_LTO=False \
      -DBUILD_TESTING=False \
      -DENABLE_JEMALLOC_GLIBC_ALLOC=False \
      -DENABLE_ASSERTIONS=False \
      -DTUNE_CPU=none \
      -DTUNE_ARCH=generic \
      -DCMAKE_TOOLCHAIN_FILE=$PWD/toolchain_mingw_arm64ec.cmake \
      -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
      -DOVERRIDE_VERSION=${fex.version}

    cmake -S . -B build_wow64 \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=/ \
      -DENABLE_LTO=False \
      -DBUILD_TESTING=False \
      -DENABLE_JEMALLOC_GLIBC_ALLOC=False \
      -DENABLE_ASSERTIONS=False \
      -DTUNE_CPU=none \
      -DTUNE_ARCH=generic \
      -DCMAKE_TOOLCHAIN_FILE=$PWD/Data/CMake/toolchain_mingw.cmake \
      -DMINGW_TRIPLE=aarch64-w64-mingw32 \
      -DOVERRIDE_VERSION=${fex.version}
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export PATH=${llvmMingwArm64ec}/bin:$PATH
    cmake --build build_arm64ec -j$NIX_BUILD_CORES
    cmake --build build_wow64 -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    export PATH=${llvmMingwArm64ec}/bin:$PATH

    DESTDIR=$PWD/install-arm64ec cmake --install build_arm64ec
    DESTDIR=$PWD/install-wow64 cmake --install build_wow64

    mkdir -p "$out/lib/wine/aarch64-windows"
    cp "$PWD/install-arm64ec/libarm64ecfex.dll" "$out/lib/wine/aarch64-windows/"
    cp "$PWD/install-wow64/libwow64fex.dll" "$out/lib/wine/aarch64-windows/"
    runHook postInstall
  '';

  dontPatchELF = true;
  dontStrip = true;

  meta = {
    description = "FEX WoA DLLs for native aarch64 Wine wow64 support";
    homepage = "https://fex-emu.com/";
    license = lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
  };
}
