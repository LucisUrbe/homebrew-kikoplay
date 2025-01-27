class Kikoplay < Formula
  desc "NOT ONLY A Full-Featured Danmu Player"
  homepage "https://github.com/KikoPlayProject/KikoPlay"
  license "GPL-3.0"

  stable do
    url "https://github.com/KikoPlayProject/KikoPlay/archive/1.0.1.tar.gz"
    sha256 "da33b02f2b4264c3040feec8a24986f323174feac3505ec52e0a68e5c9ce7b76"

    resource "script" do
      url "https://github.com/KikoPlayProject/KikoPlayScript.git",
          revision: "4c552ec13e86a055e5d1d2ea4bfb7ed2b0e54a8f"
    end
  end

  head do
    url "https://github.com/KikoPlayProject/KikoPlay.git"

    resource "script" do
      url "https://github.com/KikoPlayProject/KikoPlayScript.git"
    end
  end

  bottle do
    rebuild 1
    root_url "https://github.com/LucisUrbe/homebrew-kikoplay/releases/download/kikoplay-v1.0.1"
    sha256 cellar: :any, arm64_sonoma: "8acedee012a38fc2c264c3d8824412de5ba46b93dfa77d052bbb1732c6c7aa93"
  end

  depends_on "aria2"
  depends_on "lua@5.3"
  depends_on "mpv"
  depends_on "LucisUrbe/kikoplay/qhttpengine"
  depends_on "qt@5"

  def install
    # Enable test
    if build.head?
      system "git", "fetch", "--tags"
      version_str = Utils.safe_popen_read("git", "describe", "--tags")
      inreplace "newVersion/version.json", /(?<="Version":).*/, %Q("#{version_str}")
    end

    inreplace "main.cpp", "args.pop_front();", <<~EOS
      args.pop_front();
      if(args.at(0) == "-V")
      {
        QFile version(":/res/version.json");
        version.open(QIODevice::ReadOnly);
        QJsonObject curVersionObj = QJsonDocument::fromJson(version.readAll()).object();
        QTextStream(stderr) << qUtf8Printable(curVersionObj.value("Version").toString());
        exit(0);
      }
    EOS

    # Use relative path ($prefix/bin/..) for instead of /usr
    inreplace %W[
      LANServer/router.cpp
      Extension/Script/scriptmanager.cpp
    ] do |s|
      s.gsub! '"/usr/share', 'QCoreApplication::applicationDirPath()+"/../Resources'
    end

    # Force create ~/.config/kikoplay
    inreplace "globalobjects.cpp", "if (fileinfoConfig", "if (1 || fileinfoConfig"

    # Support native application menu
    inreplace "UI/mainwindow.cpp" do |s|
      s.gsub! /(#include <QApplication>)/,
              "#include <QMenuBar>\n\\1"
      s.gsub! /(.*QAction \*act_Settingse.*)/,
              "\\1 act_Settingse->setMenuRole(QAction::PreferencesRole);"
      s.gsub! /(.*QAction \*act_about.*)/,
              "\\1 act_about->setMenuRole(QAction::AboutRole);"
      s.gsub! /(.*QAction \*act_exit.*)/, <<~EOS
          \\1 act_exit->setMenuRole(QAction::QuitRole);
              auto *menuBar = new QMenuBar(nullptr);
              auto *appMenu = new QMenu(nullptr);
              menuBar->addMenu(appMenu);
              appMenu->addAction(act_Settingse);
              appMenu->addAction(act_about);
              appMenu->addAction(act_exit);
              setMenuBar(menuBar);
      EOS
    end

    # Fix the classical struct Extension::LuaItemRef usage.
    inreplace "Extension/App/AppWidgets/appcombo.cpp" do |s|
      s.gsub! "const int ref = appCombo->getDataRef(L, appCombo)", <<~EOS
            const int ref = appCombo->getDataRef(L, appCombo);
            Extension::LuaItemRef local_fix;
            local_fix.ref = ref;
            local_fix.tableRef = appCombo->dataRef;
      EOS
      s.gsub! "{ref, appCombo->dataRef}", "local_fix"
    end
    inreplace "Extension/App/AppWidgets/applist.cpp" do |s|
      s.gsub! "val = QVariant::fromValue<Extension::LuaItemRef>({getDataRef(L, appList), appList->dataRef});", <<~EOS
            Extension::LuaItemRef local_fix;
            local_fix.ref = getDataRef(L, appList);
            local_fix.tableRef = appList->dataRef;
            val = QVariant::fromValue<Extension::LuaItemRef>(local_fix);
      EOS
      s.gsub! "map[\"data\"] = QVariant::fromValue<Extension::LuaItemRef>({ref, appList->dataRef});", <<~EOS
            Extension::LuaItemRef local_fix;
            local_fix.ref = ref;
            local_fix.tableRef = appList->dataRef;
            map["data"] = QVariant::fromValue<Extension::LuaItemRef>(local_fix);
      EOS
    end
    inreplace "Extension/App/AppWidgets/apptree.cpp" do |s|
      s.gsub! "const int ref = appTree->getDataRef(L, appTree);", <<~EOS
            const int ref = appTree->getDataRef(L, appTree);
            Extension::LuaItemRef local_fix;
            local_fix.ref = ref;
            local_fix.tableRef = appTree->dataRef;
      EOS
      s.gsub! "{ref, appTree->dataRef}", "local_fix"
      s.gsub! "val = QVariant::fromValue<Extension::LuaItemRef>({appTree->getDataRef(L, appTree), appTree->dataRef});", <<~EOS
            Extension::LuaItemRef local_fix;
            local_fix.ref = appTree->getDataRef(L, appTree);
            local_fix.tableRef = appTree->dataRef;
            val = QVariant::fromValue<Extension::LuaItemRef>(local_fix);
      EOS
    end

    # Create icon
    mkdir "KikoPlay.iconset"
    system "sips", "-p", "128", "128",
           "kikoplay.png", "--out", "KikoPlay_Square.png"
    [16, 32, 128, 256, 512].each do |s|
      system "sips", "-z", s, s, "KikoPlay_Square.png",
                     "--out", "KikoPlay.iconset/icon_#{s}x#{s}.png"
      system "sips", "-z", s * 2, s * 2, "KikoPlay_Square.png",
                     "--out", "KikoPlay.iconset/icon_#{s}x#{s}@2x.png"
    end
    system "iconutil", "-c", "icns", "KikoPlay.iconset"

    libs = %W[
      -L#{Formula["lua@5.3"].lib}
      -L#{Formula["mpv"].lib}
      -L#{Formula["LucisUrbe/kikoplay/qhttpengine"].lib}
    ]
    system "#{Formula["qt@5"].bin}/qmake",
           "LIBS += #{libs * " "}",
           "ICON = KikoPlay.icns",
           "build.pro"

    # Use packaged Lua headers
    # ln_sf Dir[Formula["lua@5.3"].opt_include/"lua/*"], "Script/lua/"

    # Strip leading /usr during installation
    ln_s prefix, "usr"
    ENV["INSTALL_ROOT"] = "."
    system "make"

    # Move app bundle and create command line shortcut
    mkdir "usr/libexec"
    mv "KikoPlay.app", "usr/libexec"
    bin.install_symlink libexec/"KikoPlay.app/Contents/MacOS/KikoPlay"
    (libexec/"KikoPlay.app/Contents/Resources").install_symlink share/"kikoplay"

    resource("script").stage do
      (share/"kikoplay/script").install Dir["*"]
    end

    doc.install Dir["KikoPlay*.pdf"]
  end

  def caveats
    <<~EOS
      After installation, link KikoPlay app to /Applications by running:
        ln -sf #{opt_libexec}/KikoPlay.app /Applications/
    EOS
  end

  test do
    version_str = shell_output("#{bin}/KikoPlay -V 2>&1").lines.last.chomp
    assert_equal version.to_s, version_str.sub(/^.*-\d+-g/, "HEAD-")
  end
end
