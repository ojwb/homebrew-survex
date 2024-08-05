class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.10/survex-1.4.10.tar.gz"
  sha256 "98b265fd4b959adc2ed853b8638312d16935cfa32f215aec3798eb3596696297"
  head "https://git.survex.com/survex", :using => :git

  depends_on "wxwidgets"
  depends_on "gdal"
  depends_on "proj"
  depends_on "ffmpeg" => :recommended

  depends_on "gettext" => :build
  depends_on "pkg-config" => :build

  stable do
    patch :DATA
  end

  head do
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "netpbm" => :build
    depends_on "w3m" => :build
  end

  def install
    if build.head?
      system "cat /dev/null > doc/Makefile.am"
      system "autoreconf", "-fiv"
      system "git", "checkout", "INSTALL"
      system "curl https://unifoundry.com/pub/unifont/unifont-15.1.01/font-builds/unifont-15.1.01.hex.gz | gzip -d > lib/unifont.hex"
    end

    system "./configure", "--prefix=#{prefix}",
                          "--bindir=#{bin}",
                          "--mandir=#{man}",
                          "--docdir=#{doc}",
                          "--datadir=#{share}"

    if build.head?
      # Homebrew installs by default in /opt/homebrew on M1 macs and in
      # /usr/local on intel so put both on PATH with /opt/homebrew/bin
      # first so on an M1 mac we use the native version in preference to
      # running the x86 version via emulation.
      saved_path = ENV["PATH"]
      ENV.prepend_path "PATH", "/usr/local/bin"
      ENV.prepend_path "PATH", "/opt/homebrew/bin"
      system "make", "-C", "lib/icons", "Aven.iconset.zip"
      ENV["PATH"] = saved_path

      # Install Locale::PO under the temporary directory which homebrew
      # creates and sets $HOME to, and point Perl to look for modules
      # there.
      system "cpan -T -i Locale::PO < /dev/null"
      ENV["PERL5OPT"] = "-I" + ENV["HOME"] + "/perl5/lib/perl5"
    end

    system "make"
    system "make", "install"

    # Create and populate Aven.app
    system "make", "create-aven-app", "APP_PATH=Aven.app"

    ln_s ["#{bin}/aven", "#{bin}/cavern", "#{bin}/extend"], "Aven.app/Contents/MacOS"

    prefix.install "Aven.app"
  end

  def caveats
    begin
      if File.readlink("/Applications/Aven.app") == "#{prefix}/Aven.app"
        # Symlink already exists and points to our Aven.app.
        return nil
      end
    rescue SystemCallError
      # Dangling symlink or not a symlink.
    end
    return <<~EOS
      Aven.app has been installed into #{prefix}. It can be manually linked into
      the 'Applications' folder by running:
        ln -nsfF #{prefix}/Aven.app /Applications/Aven.app
    EOS
  end

  test do
    (testpath/"test.svx").write <<~EOS
      *begin test
      *cs custom "+proj=longlat +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +no_defs"
      *cs out custom "+proj=utm +zone=56 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
      *fix 0 150.020166 -33.815585 812
      0 1 10 - DOWN
      *end test
    EOS
    pos = <<~EOS
      ( Easting, Northing, Altitude )
      (224177.87, 6254297.49,   812.00 ) test.0
      (224177.87, 6254297.49,   802.00 ) test.1
    EOS

    system "#{bin}/cavern", (testpath/"test.svx")
    ENV["LC_MESSAGES"] = "C"
    system "#{bin}/survexport", (testpath/"test.3d"), (testpath/"test.pos")
    File.open(testpath/"test.pos", "r") { |f| assert_equal f.read, pos }
  end
end
