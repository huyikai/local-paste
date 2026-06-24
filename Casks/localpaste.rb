cask "localpaste" do
  version :latest
  sha256 :no_check

  url "https://github.com/huyikai/local-paste/releases/latest/download/LocalPaste.dmg",
      verified: "github.com/huyikai/local-paste/"
  name "LocalPaste"
  desc "Lightweight, local-only clipboard history manager for macOS"
  homepage "https://github.com/huyikai/local-paste"

  app "LocalPaste.app"

  zap trash: [
    "~/Library/Application Support/LocalPaste",
    "~/Library/Preferences/com.localpaste.app.plist",
  ]
end
