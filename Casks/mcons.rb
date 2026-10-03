cask "mcons" do
  version "1.0.4"
  sha256 :no_check

  url "https://github.com/neel0210/MCons/releases/download/v#{version}/MCons-v#{version}-release.dmg"
  name "MCons"
  desc "Native macOS utility for creating folders with custom icons"
  homepage "https://github.com/neel0210/MCons"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "MCons.app"

  zap trash: [
    "~/Library/Application Support/MCons",
    "~/Library/Caches/com.neel0210.mcons",
    "~/Library/Preferences/com.neel0210.mcons.plist",
  ]
end
