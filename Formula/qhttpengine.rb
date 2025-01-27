class Qhttpengine < Formula
  desc "Simple set of classes for developing HTTP server applications in Qt"
  homepage "https://github.com/nitroshare/qhttpengine"
  url "https://github.com/nitroshare/qhttpengine/archive/1.0.1.tar.gz"
  sha256 "6505cf889909dc29bab4069116656e7ca5a9e879f04935139439c5691a76c55e"
  license "MIT"
  revision 1
  head "https://github.com/nitroshare/qhttpengine.git"

  bottle do
    rebuild 1
    root_url "https://github.com/LucisUrbe/homebrew-kikoplay/releases/download/qhttpengine-v1.0.1"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "6477fc2b6624b0e578f9413eb201c0f3013ced683f05833877d9ce19565abcd7"
  end

  depends_on "cmake" => :build
  depends_on "qt@5"

  def install
    system "cmake", ".", *std_cmake_args
    system "make", "install"
  end

  test do
    (testpath/"test.pro").write <<~EOS
      TEMPLATE     = app
      CONFIG      += console
      CONFIG      -= app_bundle
      TARGET       = test
      QT          += network
      SOURCES     += test.cpp
      INCLUDEPATH += #{include}
      LIBPATH     += #{lib}
      LIBS        += -lqhttpengine
    EOS

    (testpath/"test.cpp").write <<~EOS
      #define QT_NO_SSL
      #include <QTcpSocket>
      #include <qhttpengine/server.h>
      int main() {
        QHttpEngine::Server server;
        if (!server.listen(QHostAddress::LocalHost, 18000)) {
          return 1;
        }
        QTcpSocket socket;
        socket.connectToHost(server.serverAddress(), server.serverPort());
        if (socket.waitForConnected(500)) {
          return 0;
        }
        return 1;
      }
    EOS

    system "#{Formula["qt@5"].bin}/qmake", "test.pro"
    system "make"
    assert_predicate testpath/"test", :exist?, "test output file does not exist!"
    system "./test"
  end
end
