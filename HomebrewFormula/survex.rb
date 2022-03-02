class Survex < Formula
  desc "Cave Surveying Tool"
  homepage "https://www.survex.com"
  url "https://survex.com/software/1.4.2/survex-1.4.2.tar.gz"
  sha256 "f3a584bcaccd02fde2ca1dbb575530431dc957989da224f35f8d1adec7418f1a"
  revision 2

  depends_on "wxwidgets"
  depends_on "proj"
  depends_on "ffmpeg" => :recommended

  depends_on "gettext" => :build
  depends_on "pkg-config" => :build

  option "with-debug-hacks", "Temporary option to help debug Aven startup bug"

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--bindir=#{bin}",
                          "--mandir=#{man}",
                          "--docdir=#{doc}",
                          "--datadir=#{share}"

    if build.with? "debug-hacks"
      patch :DATA
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
diff --git a/src/mainfrm.cc b/src/mainfrm.cc
index 51dd39b2..727684da 100644
--- a/src/mainfrm.cc
+++ b/src/mainfrm.cc
@@ -737,6 +737,9 @@ MainFrm::MainFrm(const wxString& title, const wxPoint& pos, const wxSize& size)
     , m_PrefsDlg(NULL)
 #endif
 {
+    const char * p = getenv("AVENHACKS");
+    if (p) hacks = atoi(p);
+
 #ifdef _WIN32
     // The peculiar name is so that the icon is the first in the file
     // (required by Microsoft Windows for this type of icon)
@@ -748,7 +751,7 @@ MainFrm::MainFrm(const wxString& title, const wxPoint& pos, const wxSize& size)
 #if wxCHECK_VERSION(3,1,0)
     // Add a full screen button to the right upper corner of title bar under OS
     // X 10.7 and later.
-    EnableFullScreenView();
+    if (!(hacks & 4)) EnableFullScreenView();
 #endif
     CreateMenuBar();
     MakeToolBar();
@@ -769,6 +772,8 @@ MainFrm::MainFrm(const wxString& title, const wxPoint& pos, const wxSize& size)
 #if wxUSE_DRAG_AND_DROP
     SetDropTarget(new DnDFile(this));
 #endif
+    printf("Main window constructed\n");
+
 }
 
 void MainFrm::CreateMenuBar()
@@ -1012,15 +1017,20 @@ void MainFrm::MakeToolBar()
     // Make the toolbar.
 
 #ifdef USING_GENERIC_TOOLBAR
-    // This OS-X-specific code is only needed to stop the toolbar icons getting
-    // scaled up, which just makes them look nasty and fuzzy.  Once we have
-    // larger versions of the icons, we can drop this code.
-    wxSystemOptions::SetOption(wxT("mac.toolbar.no-native"), 1);
-    wxToolBar* toolbar = new wxToolBar(this, wxID_ANY, wxDefaultPosition,
-				       wxDefaultSize, wxNO_BORDER|wxTB_FLAT|wxTB_NODIVIDER|wxTB_NOALIGN);
-    wxBoxSizer* sizer = new wxBoxSizer(wxVERTICAL);
-    sizer->Add(toolbar, 0, wxEXPAND);
-    SetSizer(sizer);
+    wxToolBar* toolbar;
+    if (!(hacks & 1)) {
+	// This OS-X-specific code is only needed to stop the toolbar icons getting
+	// scaled up, which just makes them look nasty and fuzzy.  Once we have
+	// larger versions of the icons, we can drop this code.
+	wxSystemOptions::SetOption(wxT("mac.toolbar.no-native"), 1);
+	toolbar = new wxToolBar(this, wxID_ANY, wxDefaultPosition,
+				wxDefaultSize, wxNO_BORDER|wxTB_FLAT|wxTB_NODIVIDER|wxTB_NOALIGN);
+	wxBoxSizer* sizer = new wxBoxSizer(wxVERTICAL);
+	sizer->Add(toolbar, 0, wxEXPAND);
+	SetSizer(sizer);
+    } else {
+	toolbar = wxFrame::CreateToolBar();
+    }
 #else
     wxToolBar* toolbar = wxFrame::CreateToolBar();
 #endif
@@ -1078,8 +1088,10 @@ void MainFrm::CreateSidePanel()
     // This OS-X-specific code is only needed to stop the toolbar icons getting
     // scaled up, which just makes them look nasty and fuzzy.  Once we have
     // larger versions of the icons, we can drop this code.
-    GetSizer()->Add(m_Splitter, 1, wxEXPAND);
-    Layout();
+    if (!(hacks & 1)) {
+	GetSizer()->Add(m_Splitter, 1, wxEXPAND);
+	Layout();
+    }
 #endif
 
     m_Notebook = new wxNotebook(m_Splitter, 400, wxDefaultPosition,
@@ -1125,6 +1137,7 @@ void MainFrm::CreateSidePanel()
     m_Notebook->AddPage(prespanel, wmsg(/*Presentation*/377), false, 1);
 
     m_Splitter->Initialize(m_Gfx);
+    if (hacks & 2) m_Gfx->Show(true);
 }
 
 bool MainFrm::LoadData(const wxString& file, const wxString& prefix)
@@ -2184,6 +2197,7 @@ void MainFrm::OnFind(wxCommandEvent&)
 
 void MainFrm::OnIdle(wxIdleEvent&)
 {
+    printf("OnIdle\n");
     if (pending_find) {
 	DoFind();
     }
@@ -2396,7 +2410,7 @@ void MainFrm::ViewFullScreen() {
 	GetStatusBar()->Show();
 	GetToolBar()->Show();
 #ifdef USING_GENERIC_TOOLBAR
-	Layout();
+	if (!(hacks & 1)) Layout();
 #endif
     }
 #endif
diff --git a/src/mainfrm.h b/src/mainfrm.h
index 34fa574a..3bf4c6b8 100644
--- a/src/mainfrm.h
+++ b/src/mainfrm.h
@@ -183,6 +183,8 @@ class MainFrm : public wxFrame, public Model {
     PrefsDlg* m_PrefsDlg;
 #endif
 
+    unsigned hacks = 0;
+
     bool ProcessSVXFile(const wxString & file);
 //    void FixLRUD(traverse & centreline);
 
@@ -194,6 +196,7 @@ class MainFrm : public wxFrame, public Model {
 
 #ifdef USING_GENERIC_TOOLBAR
     wxToolBar * GetToolBar() const {
+	if (hacks & 1) return wxFrame::GetToolBar();
 	wxSizer * sizer = GetSizer();
 	if (!sizer) return NULL;
 	return (wxToolBar*)sizer->GetItem(size_t(0))->GetWindow();
