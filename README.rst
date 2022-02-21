homebrew-survex
===============

Homebrew tap for Survex cave survey tool.

To tap this repository::

  brew tap survex/survex https://git.survex.com/homebrew-survex

Then to install Survex::

  brew install survex
  
FFmpeg is used to implement Aven's movie export feature hence it is marked as recommended dependency and installed by default. To disable this feature you can avoid FFmpeg installation by adding --without-ffmpeg parameter::

  brew install surver --without-ffmpeg
