homebrew-survex
===============

Homebrew tap for Survex cave survey tool.

To tap this repository::

  brew tap survex/survex https://git.survex.com/homebrew-survex

Then to install the latest stable version of Survex::

  brew install survex

FFmpeg is used to implement Aven's movie export feature - this homebrew package
marks it as a recommended dependency so it will be installed and used by default.
If you don't use this feature you can avoid the FFmpeg dependency by adding the
`--without-ffmpeg` option::

  brew install survex --without-ffmpeg

If you want to install the latest development version use::

  brew install inkscape
  brew install survex --HEAD

Note that installing the latest development version like this currently omits
the documentation.
