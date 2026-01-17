# App Icons Generation Guide

This directory should contain platform-specific app icons for Electron builds.

## Required Icons

- **icon.png** (1024x1024) - Linux AppImage/deb icon
- **icon.ico** (256x256) - Windows installer icon
- **icon.icns** (multiple sizes) - macOS app bundle icon

## Quick Generation

### Option 1: Using npm script (requires sharp)

```bash
# Install sharp if not already installed
npm install --save-dev sharp

# Generate icons
npm run build:icons
```

This will create:
- `icon.png` - Ready to use
- `icon-256.png` - Temporary file for ICO conversion
- `icons.iconset/` - Directory with all macOS sizes

### Option 2: Using ImageMagick (command line)

```bash
# Install ImageMagick first
# Ubuntu/Debian: sudo apt-get install imagemagick
# macOS: brew install imagemagick
# Windows: https://imagemagick.org/script/download.php

# From public/ directory:

# Generate PNG
convert favicon.svg -resize 1024x1024 icon.png

# Generate ICO (Windows)
convert favicon.svg -resize 256x256 icon-256.png
convert icon-256.png -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico

# Generate ICNS (macOS)
mkdir -p icons.iconset
convert favicon.svg -resize 16x16 icons.iconset/icon_16x16.png
convert favicon.svg -resize 32x32 icons.iconset/icon_16x16@2x.png
convert favicon.svg -resize 32x32 icons.iconset/icon_32x32.png
convert favicon.svg -resize 64x64 icons.iconset/icon_32x32@2x.png
convert favicon.svg -resize 128x128 icons.iconset/icon_128x128.png
convert favicon.svg -resize 256x256 icons.iconset/icon_128x128@2x.png
convert favicon.svg -resize 256x256 icons.iconset/icon_256x256.png
convert favicon.svg -resize 512x512 icons.iconset/icon_256x256@2x.png
convert favicon.svg -resize 512x512 icons.iconset/icon_512x512.png
convert favicon.svg -resize 1024x1024 icons.iconset/icon_512x512@2x.png

# Convert iconset to ICNS (macOS only)
iconutil -c icns icons.iconset -o icon.icns

# Clean up temporary files
rm -rf icons.iconset icon-256.png
```

### Option 3: Online Tools (No installation needed)

**For ICO (Windows):**
1. Go to https://convertio.co/png-ico/
2. Upload `favicon.svg` or `icon-256.png`
3. Set size to 256x256
4. Download as `icon.ico`

**For ICNS (macOS):**
1. Go to https://cloudconvert.com/png-to-icns
2. Upload `icon.png` (1024x1024)
3. Download as `icon.icns`

**For PNG:**
1. Go to https://convertio.co/svg-png/
2. Upload `favicon.svg`
3. Set size to 1024x1024
4. Download as `icon.png`

## GitHub Actions Auto-Generation

The `.github/workflows/release.yml` workflow includes automatic icon generation.
If icons are missing, they will be generated from `favicon.svg` during the build.

## Manual Creation (Recommended for best quality)

For production releases, it's recommended to:

1. Create a high-quality design in a vector editor (Figma, Illustrator, Inkscape)
2. Export at exact sizes:
   - PNG: 1024x1024 with transparency
   - ICO: 256x256
   - ICNS: Create an iconset with all required sizes

3. Save in this directory

## Icon Design Guidelines

### Windows (ICO)
- Size: 256x256 (will auto-resize to 16, 32, 48, 64, 128, 256)
- Format: ICO with transparency
- Background: Transparent or white
- Padding: 10% around the icon

### macOS (ICNS)
- Size: 1024x1024 base (retina)
- Format: ICNS with multiple resolutions
- Background: Transparent
- Rounded corners: Not needed (macOS handles this)

### Linux (PNG)
- Size: 1024x1024 or 512x512
- Format: PNG with transparency
- Background: Transparent

## Current Icon

The current `favicon.svg` features:
- Green gradient robot head (#10b981 to #14b8a6)
- Simple, recognizable design
- Works well at all sizes

## Troubleshooting

### "icon.ico not found" during Windows build
Run: `npm run build:icons` or use ImageMagick to create from SVG

### "icon.icns not found" during macOS build
electron-builder can auto-convert from icon.png on macOS systems
Or manually create using iconutil (macOS only)

### Icons look blurry
Ensure source image is high resolution (1024x1024 minimum)
SVG provides best quality for all sizes

## Cleanup

After generating icons, you can safely delete:
- `icon-256.png` (temporary file)
- `icons.iconset/` (after creating ICNS)
