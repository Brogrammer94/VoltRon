# SVS Format Support for Xenium H&E Alignment

## Overview

The `addXeniumHE()` function now fully supports **SVS (Aperio ScanScope Virtual Slide)** format, which is commonly used for whole slide imaging in pathology.

## What is SVS?

SVS is a proprietary whole slide imaging format that contains:
- Multiple resolution levels (pyramidal structure)
- Full resolution image at level 1
- Progressively lower resolutions at higher levels
- Typical SVS files: 5-7 resolution levels

## Usage

### Basic (Auto-Resolution)

```r
# SVS files are automatically detected
xenium <- addXeniumHE(xenium, "post_xenium_he_image.svs")
```

The function will:
1. Detect the SVS format
2. Display available resolution levels
3. Auto-select an optimal level (typically level 2-3)
4. Perform alignment

### Manual Resolution Selection

```r
# Specify resolution level manually
xenium <- addXeniumHE(
  xenium,
  "post_xenium_he_image.svs",
  svs_resolution = 2,  # Level 2
  verbose = TRUE
)
```

## Resolution Level Guidelines

| Level | Typical Size | Use Case | Speed |
|-------|-------------|----------|-------|
| 1 | 40,000+ × 30,000+ | Highest quality alignment | Slow |
| 2 | 10,000 × 7,500 | Recommended for alignment | Medium |
| 3 | 5,000 × 3,750 | Good for large files | Fast |
| 4+ | 2,500 × 1,875 | Quick preview/testing | Very Fast |

## When to Use Different Levels

**Level 1-2 (High Resolution):**
- Small to medium SVS files (<5 GB)
- Need maximum alignment accuracy
- Have sufficient RAM and time

**Level 2-3 (Mid Resolution - RECOMMENDED):**
- Most use cases
- Good balance of speed and accuracy
- Default auto-selection

**Level 3-4 (Lower Resolution):**
- Very large SVS files (>10 GB)
- Quick testing/preview
- Limited computational resources

## Requirements

SVS format requires the **RBioFormats** package:

```r
# Install RBioFormats
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install("RBioFormats")
```

## Example Workflow

```r
library(VoltRon)

# Import Xenium data
xenium <- importXenium("Xenium_R1/outs", sample_name = "Sample1")

# Add SVS H&E with auto-resolution (easiest)
xenium <- addXeniumHE(
  xenium,
  "post_xenium_he.svs",
  verbose = TRUE  # Shows available resolutions
)

# Check what was loaded
vrImageChannelNames(xenium)

# View aligned H&E
vrImages(xenium, channel = "H&E")

# Visualize genes on H&E background
vrSpatialFeaturePlot(xenium, features = "ERBB2", channel = "H&E")
```

## Advanced: Fine-tuning for SVS

For large SVS files, you may need to adjust alignment parameters:

```r
xenium <- addXeniumHE(
  xenium,
  "large_he_image.svs",
  svs_resolution = 3,           # Use lower resolution
  MAX_FEATURES = 1000,          # More features for better matching
  GOOD_MATCH_PERCENT = 0.20,    # Stricter matching
  matcher = "BRUTE-FORCE",      # More accurate matcher
  method = "Homography+Non-Rigid"  # Handle tissue deformation
)
```

## Troubleshooting

### Error: "SVS formats require the RBioFormats package"
**Solution:** Install RBioFormats as shown above

### Error: Memory issues with large SVS files
**Solution:** Use higher resolution level (3 or 4):
```r
xenium <- addXeniumHE(xenium, "file.svs", svs_resolution = 3)
```

### Poor alignment quality
**Solution:** Try different resolution levels:
```r
# Try level 2 (higher quality)
xenium <- addXeniumHE(xenium, "file.svs", svs_resolution = 2, MAX_FEATURES = 1000)
```

### How to check available resolutions
**Solution:** Use verbose mode:
```r
xenium <- addXeniumHE(xenium, "file.svs", verbose = TRUE)
# This will print all available resolution levels and their dimensions
```

## Other Supported Formats

In addition to SVS, the function supports:
- **Standard formats:** TIFF, PNG, JPEG, BMP
- **Pyramidal formats:** OME-TIFF, SVS
- Any format supported by ImageMagick or Bio-Formats

## Performance Tips

1. **Start with auto-selection** - The function chooses a good default
2. **Use verbose mode** - See what's happening and available options
3. **Large files (>10 GB)** - Use `svs_resolution = 3` or higher
4. **Small files (<5 GB)** - Use `svs_resolution = 2` for best quality
5. **Testing** - Use high resolution level (4-5) for quick tests

## Summary

✅ SVS files work automatically - just pass the path
✅ Auto-resolution selection works well for most cases
✅ Manual control available via `svs_resolution` parameter
✅ Full resolution pyramid support
✅ Same simple workflow as other formats

For any issues or questions, refer to the comprehensive examples in:
`examples/xenium_he_alignment_example.R`
