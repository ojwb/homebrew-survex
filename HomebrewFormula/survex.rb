class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.2/survex-1.4.2.tar.gz"
  sha256 "f3a584bcaccd02fde2ca1dbb575530431dc957989da224f35f8d1adec7418f1a"
  revision 5

  depends_on "wxwidgets"
  depends_on "proj"
  depends_on "ffmpeg" => :recommended

  depends_on "gettext" => :build
  depends_on "pkg-config" => :build

  patch :DATA

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

__END__
diff --git a/src/aven.cc b/src/aven.cc
index 24a25ef8..f70c78ce 100644
--- a/src/aven.cc
+++ b/src/aven.cc
@@ -357,6 +357,11 @@ bool Aven::OnInit()
     if (utf8_argv[optind]) {
 	if (!opt_survey) opt_survey = "";
 	m_Frame->OpenFile(fnm, wxString(opt_survey, wxConvUTF8));
+    } else {
+#ifdef __WXMAC__
+	// On macos we seem to need to draw the "empty" window using OpenGL.
+	m_Frame->OpenFile(wxString(), wxString());
+#endif
     }
 
     if (print_and_exit) {
diff --git a/src/gfxcore.cc b/src/gfxcore.cc
index 8d652969..6eae685d 100644
--- a/src/gfxcore.cc
+++ b/src/gfxcore.cc
@@ -210,7 +210,7 @@ void GfxCore::TryToFreeArrays()
 //  Initialisation methods
 //
 
-void GfxCore::Initialise(bool same_file)
+void GfxCore::Initialise(bool same_file, bool have_data)
 {
     // Initialise the view from the parent holding the survey data.
 
@@ -229,7 +229,7 @@ void GfxCore::Initialise(bool same_file)
 	DefaultParameters();
     }
 
-    m_HaveData = true;
+    m_HaveData = have_data;
 
     // Clear any cached OpenGL lists which depend on the data.
     InvalidateList(LIST_SCALE_BAR);
@@ -375,9 +375,6 @@ void GfxCore::OnPaint(wxPaintEvent&)
 {
     // Redraw the window.
 
-    // Get a graphics context.
-    wxPaintDC dc(this);
-
     if (m_HaveData) {
 	// Make sure we're initialised.
 	bool first_time = !m_DoneFirstShow;
@@ -557,8 +554,19 @@ void GfxCore::OnPaint(wxPaintEvent&)
 
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
+	// Get a graphics context.
+	wxPaintDC dc(this);
 	dc.SetBackground(wxSystemSettings::GetColour(wxSYS_COLOUR_WINDOWFRAME));
 	dc.Clear();
+#endif
     }
 }
 
diff --git a/src/gfxcore.h b/src/gfxcore.h
index 758c8d3a..1c7b4c11 100644
--- a/src/gfxcore.h
+++ b/src/gfxcore.h
@@ -358,7 +358,7 @@ public:
     GfxCore(MainFrm* parent, wxWindow* parent_window, GUIControl* control);
     ~GfxCore();
 
-    void Initialise(bool same_file);
+    void Initialise(bool same_file, bool have_data = true);
 
     void UpdateBlobs();
     void ForceRefresh();
diff --git a/src/gla-gl.cc b/src/gla-gl.cc
index 643a1ab8..d879a2d9 100644
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
index 51dd39b2..f1066d7a 100644
--- a/src/mainfrm.cc
+++ b/src/mainfrm.cc
@@ -1295,6 +1295,12 @@ void MainFrm::OpenFile(const wxString& file, const wxString& survey)
 	}
     }
 
+    if (file.empty()) {
+	m_Gfx->Initialise(false, false);
+	m_Gfx->Show(true);
+	return;
+    }
+
     if (!LoadData(file, survey))
 	return;
     AddToFileHistory(file);
