homebrew-survex
===============

Homebrew tap for Survex cave survey tool.

To tap this repository::

  brew tap survex/survex https://git.survex.com/homebrew-survex

Then to install the latest stable version of Survex::

  brew install survex

Once you have an install, you can upgrade it to the latest stable version::

  brew update
  brew upgrade survex

FFmpeg is used to implement Aven's movie export feature - this homebrew package
marks it as a recommended dependency so it will be installed and used by
default.  If you don't use this feature you can avoid the FFmpeg dependency by
adding the `--without-ffmpeg` option::

  brew install survex --without-ffmpeg

Development version
-------------------

For general use we recommend using the stable version, but if you want to help
with testing you can install the latest development version with::

  brew install inkscape
  brew install survex --HEAD

(If you already have the stable version installed, you may first need to
``brew unlink survex``.)

If you later want to upgrade an install of the development version then use::

  brew update
  brew upgrade survex --fetch-HEAD

Note that installing the latest development version like this currently omits
the documentation.
