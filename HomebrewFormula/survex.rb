class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.1/survex-1.4.1.tar.gz"
  sha256 "ebd5f58c68c14d0210ce40f5993653cc4f0bfc65e79dfe52239da5ede2222f3e"
  revision 2

  depends_on "wxwidgets"
  depends_on "proj"
  depends_on "ffmpeg"

  depends_on "gettext" => :build
  depends_on "pkg-config" => :build

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--bindir=#{bin}",
                          "--mandir=#{man}",
                          "--docdir=#{doc}",
                          "--datadir=#{share}"

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
