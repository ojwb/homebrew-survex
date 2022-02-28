class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.2/survex-1.4.2.tar.gz"
  sha256 "f3a584bcaccd02fde2ca1dbb575530431dc957989da224f35f8d1adec7418f1a"
  head "https://git.survex.com/survex", :using => :git

  depends_on "wxwidgets"
  depends_on "proj"
  depends_on "ffmpeg" => :recommended

  depends_on "gettext" => :build
  depends_on "pkg-config" => :build

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
      system "curl https://unifoundry.com/pub/unifont/unifont-14.0.01/font-builds/unifont-14.0.01.hex.gz | gzip -d > lib/unifont.hex"
    end

    system "./configure", "--prefix=#{prefix}",
                          "--bindir=#{bin}",
                          "--mandir=#{man}",
                          "--docdir=#{doc}",
                          "--datadir=#{share}"

    if build.head?
      ENV.prepend_path "PATH", "/opt/homebrew/bin"
      system "cd lib/icons ; make Aven.iconset.zip"
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
