{
  gawk,
  findutils,
  perl,
}:

let
  fromAppxManifests = root: ''
    ${findutils}/bin/find "${root}" -name AppxManifest.xml -type f -print0 2>/dev/null \
      | ${findutils}/bin/xargs -0 -r ${perl}/bin/perl -0ne '
        while (/<(?:[A-Za-z0-9_.-]+:)?Extension\b[^>]*\bCategory="windows\.protocol"[^>]*>(.*?)<\/(?:[A-Za-z0-9_.-]+:)?Extension>/sg) {
          my $extension = $1;
          while ($extension =~ /<(?:[A-Za-z0-9_.-]+:)?Protocol\b[^>]*\bName="([^"]+)"/sg) {
            print "$1\n";
          }
        }
      '
  '';

  fromWineRegistries = root: ''
    for reg_file in "${root}/user.reg" "${root}/system.reg" "${root}/userdef.reg"; do
      [ -f "$reg_file" ] || continue
      ${gawk}/bin/awk '
        /^\[Software\\\\(Wow6432Node\\\\)?Classes\\\\[^\\\]]+\]/ {
          section = $0
          sub(/^\[Software\\\\(Wow6432Node\\\\)?Classes\\\\/, "", section)
          sub(/\].*$/, "", section)
          scheme = section
          if (scheme ~ /\\\\/) scheme = ""
        }
        /^"URL Protocol"=/ && scheme != "" {
          print scheme
        }
      ' "$reg_file"
    done
  '';
in
{
  inherit fromAppxManifests fromWineRegistries;

  fromWindowsMetadata = root: ''
    ${fromAppxManifests root}
    ${fromWineRegistries root}
  '';
}
