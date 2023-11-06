{ stdenv

, meson
, ninja

, pkg-config
, vala

, glib
, gtk4
, webkitgtk_6_0
, glib-networking
, json-glib

, fabric-ui
}:

stdenv.mkDerivation {
  pname = "fabric.applications.webapp";
  version = "0.1";

  src = ./.;

  buildInputs = [
    glib
    gtk4
    webkitgtk_6_0
    glib-networking
    json-glib
    fabric-ui
  ];

  nativeBuildInputs = [
    meson
    ninja

    pkg-config
    vala
  ];

  preConfigure = ''
    mesonFlags+=" -Dgio_modules=${glib-networking}/lib/gio/modules "
  '';

  GIO_MODULES = [
    "${glib-networking}/lib/gio/modules"
  ];
}
