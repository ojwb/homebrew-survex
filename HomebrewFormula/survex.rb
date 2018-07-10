class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.2.35/survex-1.2.35.tar.gz"
  sha256 "91efc72471637efa33fe04b6d154e493ece4c6ce694b1f95e3d6289c0e5c640f"

  depends_on "wxmac"
  depends_on "proj"
  depends_on "ffmpeg"

  depends_on "gettext" => :build

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

    prefix.install "Aven.app"
  end

  test do
    Dir.chdir("tests") do
      ENV["CAVERN"] = "#{bin}/cavern"
      ENV["DIFFPOS"] = "#{bin}/diffpos"
      ENV["SURVEXPORT"] = "#{bin}/survexport"
      ENV["VERBOSE"] = "1"
      system "./cavern.tst"
    end
  end
end
