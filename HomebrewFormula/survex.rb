class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.2/survex-1.4.2.tar.gz"
  sha256 "f3a584bcaccd02fde2ca1dbb575530431dc957989da224f35f8d1adec7418f1a"
  revision 6
  head "https://git.survex.com/survex", :using => :git

  depends_on "wxwidgets"
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
      system "curl https://unifoundry.com/pub/unifont/unifont-14.0.01/font-builds/unifont-14.0.01.hex.gz | gzip -d > lib/unifont.hex"
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
      ENV.prepend_path "PATH", "/usr/local/bin"
      ENV.prepend_path "PATH", "/opt/homebrew/bin"
      system "make", "-C", "lib/icons", "Aven.iconset.zip"

      ENV["PERL5OPT"] = "-I" + ENV["HOME"] + "/perl5/lib/perl5 -Mlocal::lib"
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

__END__
diff --git a/src/gfxcore.cc b/src/gfxcore.cc
index 8d652969..f542bb2f 100644
--- a/src/gfxcore.cc
+++ b/src/gfxcore.cc
@@ -557,8 +557,17 @@ void GfxCore::OnPaint(wxPaintEvent&)
 
 	FinishDrawing();
     } else {
+#ifdef __WXMAC__
+	if (!m_DoneFirstShow) {
+	    FirstShow();
+	}
+	StartDrawing();
+	ClearNative();
+	FinishDrawing();
+#else
 	dc.SetBackground(wxSystemSettings::GetColour(wxSYS_COLOUR_WINDOWFRAME));
 	dc.Clear();
+#endif
     }
 }
 
diff --git a/src/gla-gl.cc b/src/gla-gl.cc
index 643a1ab8..86c06936 100644
--- a/src/gla-gl.cc
+++ b/src/gla-gl.cc
@@ -619,6 +619,22 @@ void GLACanvas::Clear()
     CHECK_GL_ERROR("Clear", "glClear");
 }
 
+void GLACanvas::ClearNative()
+{
+    // Clear the canvas to the native background colour.
+
+    wxColour background_colour = wxSystemSettings::GetColour(wxSYS_COLOUR_WINDOWFRAME);
+    glClearColor(background_colour.Red() / 255.,
+		 background_colour.Green() / 255.,
+		 background_colour.Blue() / 255.,
+		 1.0);
+    CHECK_GL_ERROR("ClearNative", "glClearColor");
+    glClear(GL_COLOR_BUFFER_BIT);
+    CHECK_GL_ERROR("ClearNative", "glClear");
+    glClearColor(0.0, 0.0, 0.0, 1.0);
+    CHECK_GL_ERROR("ClearNative", "glClearColor (2)");
+}
+
 void GLACanvas::SetScale(Double scale)
 {
     if (scale != m_Scale) {
diff --git a/src/gla.h b/src/gla.h
index b5ce1b38..f12cc8b5 100644
--- a/src/gla.h
+++ b/src/gla.h
@@ -167,6 +167,7 @@ public:
     void FirstShow();
 
     void Clear();
+    void ClearNative();
     void StartDrawing();
     void FinishDrawing();
 
diff --git a/src/mainfrm.cc b/src/mainfrm.cc
index 51dd39b2..9fefa516 100644
--- a/src/mainfrm.cc
+++ b/src/mainfrm.cc
@@ -769,6 +769,11 @@ MainFrm::MainFrm(const wxString& title, const wxPoint& pos, const wxSize& size)
 #if wxUSE_DRAG_AND_DROP
     SetDropTarget(new DnDFile(this));
 #endif
+
+#ifdef __WXMAC__
+    m_Gfx->ForceRefresh();
+    m_Gfx->Show(true);
+#endif
 }
 
 void MainFrm::CreateMenuBar()
