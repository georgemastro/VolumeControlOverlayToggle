class VolumeIconToggle < Formula
  desc "A simple macOS menu bar app to toggle the volume icon"
  homepage "https://github.com/georgemastro/VolumeIconToggle"
  url "https://github.com/georgemastro/VolumeIconToggle.git"
  version "1.0.0"
  
  depends_on xcode: ["13.0", :build]
  depends_on macos: ["13.0"]

  def install
    system "swift", "build", "--configuration", "release"
    bin.install ".build/release/VolumeIconToggle"
  end

  service do
    run opt_bin/"VolumeIconToggle"
    keep_alive true
    log_path var/"log/volume-icon-toggle.log"
    error_log_path var/"log/volume-icon-toggle.log"
  end

  test do
    system "#{bin}/VolumeIconToggle", "--version"
  end
end 