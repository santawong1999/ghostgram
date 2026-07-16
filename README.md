TGExtra+
=======

Enhanced Telegram iOS with:

- **Anti-Revoke**: Keep messages even after sender deletes them
- **View-Once Photo**: Save self-destructing photos
- **View-Once Video**: Save self-destructing videos  
- **Forward Bypass**: Save/copy protected content
- **Ghost Mode**: Hide online/typing status
- **No Read Receipt**: Read messages without seen marks
- **Block Ads**: Remove sponsored messages

## How to Use

1. Install the built IPA via AltStore/Sideloadly
2. In Telegram, long-press with **3 fingers** for 0.5 seconds
3. Toggle features on/off
4. No restart required

## Build

Trigger the GitHub Actions workflow, or build locally:
```
clang -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
  -miphoneos-version-min=14.0 -fobjc-arc \
  -framework Foundation -framework UIKit -framework CoreGraphics \
  -dynamiclib -O2 -o TGExtraPlus.dylib Sources/tgapi/TGExtraPlus.m \
  -install_name @rpath/TGExtraPlus.dylib
```

Then inject into a decrypted Telegram IPA and resign.
