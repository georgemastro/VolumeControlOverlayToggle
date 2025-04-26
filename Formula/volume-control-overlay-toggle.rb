class VolumeControlOverlayToggle < Formula
  desc "A simple macOS menu bar app to toggle the volume control overlay"
  homepage "https://github.com/georgemastro/VolumeControlOverlayToggle"
  url "https://github.com/georgemastro/VolumeControlOverlayToggle/archive/refs/tags/v1.0.2.tar.gz"
  sha256 "a2817f28fb78089e75c00ef72c3eb96697a83a80bc83747d37c01622bc9c1dff"
  version "1.0.2"
  
  depends_on xcode: ["12.0", :build]
  depends_on macos: :big_sur

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/VolumeControlOverlayToggle"
  end

  service do
    run [opt_bin/"VolumeControlOverlayToggle"]
    keep_alive true
    log_path var/"log/volume-control-overlay-toggle.log"
    error_log_path var/"log/volume-control-overlay-toggle.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_predicate bin/"VolumeControlOverlayToggle", :exist?
  end
end 