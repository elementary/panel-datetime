# Wingpanel Date &amp; Time Indicator
[![Packaging status](https://repology.org/badge/tiny-repos/wingpanel-indicator-datetime.svg)](https://repology.org/metapackage/wingpanel-indicator-datetime)
[![Translation status](https://l10n.elementary.io/widgets/wingpanel/-/wingpanel-indicator-datetime/svg-badge.svg)](https://l10n.elementary.io/engage/wingpanel/?utm_source=widget)

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* gobject-introspection
* libadwaita-1-dev
* libecal1.2-dev
* libedataserver1.2-dev
* libical-dev
* libgranite-7-dev >= 7.6.0
* libwingpanel-9-dev
* meson (>= 0.57.0)
* valac >= 0.40.3

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
