# Solution: When SVS Files Cannot Be Read

## Your Situation

You have SVS format H&E images that cannot be read directly by OpenSlide or RBioFormats. This is a common issue with certain SVS files.

## Quick Solution

**Convert your SVS file to TIFF first, then use the TIFF with VoltRon.**

---

## Method 1: QuPath (EASIEST - Recommended)

This is the fastest and most reliable method.

### Steps:

1. **Download QuPath** (free): https://qupath.github.io/
   - Available for Windows, Mac, Linux

2. **Open your SVS file:**
   ```
   QuPath → File → Open → Select your .svs file
   ```

3. **Export as TIFF:**
   ```
   File → Export images → Original pixels
   ```
   - Choose output directory
   - Select **TIFF** format
   - Click **Export**

4. **Use with VoltRon:**
   ```r
   library(VoltRon)

   xenium <- importXenium("Xenium_R1/outs", sample_name = "Sample1")

   # Use the converted TIFF file
   xenium <- addXeniumHE(xenium, "exported_from_qupath.tif")
   ```

**That's it!** QuPath handles all the complexity for you.

---

## Method 2: ImageJ/FIJI (Also Easy)

If you prefer ImageJ:

1. **Download FIJI**: https://fiji.sc/

2. **Open SVS:**
   ```
   File → Open → Select .svs file
   ```
   (Bio-Formats plugin will open it automatically)

3. **Export as TIFF:**
   ```
   File → Save As → Tiff
   ```

4. **Use with VoltRon:**
   ```r
   xenium <- addXeniumHE(xenium, "exported_from_fiji.tif")
   ```

---

## Method 3: Command-Line (Fastest for Scripting)

If you have `vips` installed:

```bash
# Install vips first
# macOS:
brew install vips

# Ubuntu/Debian:
sudo apt-get install libvips-tools

# Convert SVS to TIFF
vips copy input.svs output.tif

# Or extract specific resolution level (faster)
vips copy input.svs[level=2] output.tif
```

Then in R:
```r
xenium <- addXeniumHE(xenium, "output.tif")
```

---

## Method 4: Python Script (Automated)

VoltRon can generate a Python conversion script for you:

```r
# In R, generate the conversion script
createSVSConversionScript()
```

This creates `convert_svs.py`. Then:

```bash
# Install requirements (one-time)
pip install openslide-python Pillow

# Convert your SVS file
python convert_svs.py my_he_image.svs converted.tif 2
```

Then use in R:
```r
xenium <- addXeniumHE(xenium, "converted.tif")
```

---

## Choosing Resolution Level

When converting, you can extract different resolution levels:

| Level | Typical Size | Best For | Speed |
|-------|--------------|----------|-------|
| 0-1 | 40,000 × 30,000 | Small files (<5GB), max quality | Slow |
| **2** | 10,000 × 7,500 | **Most cases (RECOMMENDED)** | Medium |
| 3 | 5,000 × 3,750 | Large files (>10GB) | Fast |

**Recommendation:** Start with level 2. It provides excellent alignment quality at reasonable speed.

---

## Complete Example Workflow

```r
library(VoltRon)

# 1. Import Xenium data
xenium <- importXenium("Xenium_R1/outs", sample_name = "Sample1")

# 2. Convert SVS to TIFF using QuPath or vips (outside of R)
#    - QuPath: File → Export images → TIFF
#    - OR vips: vips copy input.svs[level=2] output.tif

# 3. Use converted TIFF file
xenium <- addXeniumHE(
  xenium,
  "converted_he_image.tif",  # Your converted file
  channel_name = "H&E",
  verbose = TRUE
)

# 4. Visualize
vrImages(xenium, channel = "H&E")
vrSpatialFeaturePlot(xenium, features = "ERBB2", channel = "H&E")
```

---

## Troubleshooting

### Q: Which method should I use?

**A:** QuPath is the easiest and most reliable. Use it if you're not comfortable with command-line tools.

### Q: The converted TIFF is huge (>5 GB)

**A:** Export at a lower resolution level:
- QuPath: Use downsample option
- vips: `vips copy input.svs[level=3] output.tif`
- Python: Change `level = 2` to `level = 3`

### Q: Conversion is very slow

**A:** Use a lower resolution level (level 3 instead of 2). The alignment will still work well.

### Q: Can I automate this for multiple files?

**A:** Yes! Use the Python script or vips in a batch script:

```bash
# Bash script to convert multiple SVS files
for file in *.svs; do
    vips copy "${file}"[level=2] "${file%.svs}.tif"
done
```

Then in R:
```r
# Process all converted TIFF files
tiff_files <- list.files(pattern = "\\.tif$")
for (tiff_file in tiff_files) {
  xenium <- addXeniumHE(xenium, tiff_file)
}
```

---

## Why Does This Happen?

SVS files from different scanner manufacturers (Aperio, Hamamatsu, 3DHistech, etc.) can have slightly different internal formats. Some SVS files:

- Use proprietary compression
- Have non-standard metadata
- Are created with scanner-specific features
- May be corrupted during transfer

**The solution** is to convert to a standard TIFF format that all tools can read reliably.

---

## Additional Help

If you need more detailed instructions:

```r
# View full conversion workflow guide
convertSVSWorkflow()

# Diagnose your specific SVS file
diagnoseSVS("path/to/your_file.svs")

# Create automated Python conversion script
createSVSConversionScript()
```

---

## Summary

✅ **Use QuPath** to export SVS → TIFF (easiest)
✅ **Use level 2** for best balance of quality and speed
✅ **Then use the TIFF** with `addXeniumHE()`

**No need to wrestle with OpenSlide or RBioFormats!** Just convert once, then it works perfectly.

---

Need help? The conversion tools handle all the complexity for you. You just need to:
1. Open SVS in QuPath
2. Export as TIFF
3. Use the TIFF in VoltRon

That's it! ✨
