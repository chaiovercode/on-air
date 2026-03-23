cask "onair" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/OWNER/OnAir/releases/download/v#{version}/OnAir-#{version}.dmg"
  name "OnAir"
  desc "Menu bar meeting countdown with dramatic audio alerts"
  homepage "https://github.com/OWNER/OnAir"

  app "OnAir.app"

  zap trash: [
    "~/Library/Application Support/OnAir",
    "~/Library/Preferences/com.onair.app.plist",
  ]
end
