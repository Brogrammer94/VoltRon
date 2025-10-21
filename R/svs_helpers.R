####
# SVS Helper Functions for Troubleshooting ####
####

#' Diagnose SVS File Issues
#'
#' This function helps diagnose why an SVS file might not be loading and
#' provides suggestions for conversion or alternative approaches.
#'
#' @param svs_path Path to the SVS file
#'
#' @return A list with diagnostic information
#'
#' @examples
#' \dontrun{
#' # Diagnose SVS file issues
#' diag <- diagnoseSVS("my_file.svs")
#' print(diag)
#' }
#'
#' @export
diagnoseSVS <- function(svs_path) {
  if (!file.exists(svs_path)) {
    stop("File not found: ", svs_path)
  }

  message("Diagnosing SVS file: ", svs_path)
  message("File size: ", round(file.size(svs_path) / 1024^3, 2), " GB")

  results <- list(
    file_path = svs_path,
    file_size_gb = round(file.size(svs_path) / 1024^3, 2),
    rbioformats_available = FALSE,
    rbioformats_works = FALSE,
    magick_works = FALSE,
    recommendations = character()
  )

  # Check RBioFormats
  if (requireNamespace('RBioFormats', quietly = TRUE)) {
    results$rbioformats_available <- TRUE
    message("✓ RBioFormats is installed")

    tryCatch({
      meta <- RBioFormats::read.metadata(svs_path)
      results$rbioformats_works <- TRUE
      results$n_series <- length(meta$sizeX)
      results$n_resolutions <- meta$resolutionCount
      results$dimensions <- paste0(meta$sizeX[1], " x ", meta$sizeY[1])
      message("✓ RBioFormats can read this file")
      message("  - Number of series: ", results$n_series)
      message("  - Number of resolutions: ", results$n_resolutions)
      message("  - Main image size: ", results$dimensions)
    }, error = function(e) {
      results$rbioformats_works <<- FALSE
      results$rbioformats_error <<- as.character(e)
      message("✗ RBioFormats cannot read this file")
      message("  Error: ", as.character(e))
    })
  } else {
    message("✗ RBioFormats not installed")
    results$recommendations <- c(
      results$recommendations,
      "Install RBioFormats: BiocManager::install('RBioFormats')"
    )
  }

  # Check ImageMagick
  tryCatch({
    img <- magick::image_read(svs_path)
    results$magick_works <- TRUE
    info <- magick::image_info(img)
    results$magick_dimensions <- paste0(info$width, " x ", info$height)
    message("✓ ImageMagick can read this file")
    message("  - Image size: ", results$magick_dimensions)
  }, error = function(e) {
    results$magick_works <- FALSE
    results$magick_error <- as.character(e)
    message("✗ ImageMagick cannot read this file")
    message("  Error: ", as.character(e))
  })

  # Provide recommendations
  if (!results$rbioformats_works && !results$magick_works) {
    message("\n⚠ RECOMMENDATIONS:")
    message("1. Convert SVS to TIFF using external tools (see ?convertSVStoTIFF)")
    message("2. Try using QuPath to export the image as TIFF")
    message("3. Use ImageJ/FIJI with Bio-Formats plugin to export")
    message("4. Use the command-line tool 'vips' to convert: vips copy input.svs output.tif")

    results$recommendations <- c(
      results$recommendations,
      "Convert SVS to TIFF format using external tools",
      "See documentation: ?convertSVStoTIFF or ?convertSVSWorkflow"
    )
  }

  return(invisible(results))
}


#' Convert SVS to TIFF Workflow Documentation
#'
#' This function provides detailed instructions for converting SVS files to
#' TIFF format using various tools when direct SVS reading fails.
#'
#' @export
convertSVSWorkflow <- function() {
  cat("
================================================================================
                    SVS to TIFF Conversion Workflow
================================================================================

If VoltRon cannot read your SVS file directly, you can convert it to TIFF
using one of these methods:

--------------------------------------------------------------------------------
METHOD 1: Using QuPath (Recommended - Free, Easy, Cross-platform)
--------------------------------------------------------------------------------

1. Download and install QuPath: https://qupath.github.io/

2. Open QuPath and load your SVS file:
   - File → Open → Select your .svs file

3. Export as TIFF:
   - File → Export images → Original pixels
   - Choose export directory
   - Select 'TIFF' as format
   - Click 'Export'

4. Use the exported TIFF with VoltRon:
   xenium <- addXeniumHE(xenium, 'exported_image.tif')

--------------------------------------------------------------------------------
METHOD 2: Using ImageJ/FIJI (Free, Cross-platform)
--------------------------------------------------------------------------------

1. Download FIJI: https://fiji.sc/

2. Install Bio-Formats plugin (usually pre-installed in FIJI)

3. Open SVS file:
   - File → Open → Select your .svs file
   - Bio-Formats will open it

4. Export as TIFF:
   - Image → Type → RGB Color (if needed)
   - File → Save As → Tiff
   - Save the file

5. Use with VoltRon:
   xenium <- addXeniumHE(xenium, 'exported_image.tif')

--------------------------------------------------------------------------------
METHOD 3: Using vips (Command-line, Fast, All platforms)
--------------------------------------------------------------------------------

1. Install vips:
   - macOS: brew install vips
   - Ubuntu/Debian: sudo apt-get install libvips-tools
   - Windows: Download from https://github.com/libvips/libvips/releases

2. Convert SVS to TIFF:
   vips copy input.svs output.tif

3. For specific resolution level (faster):
   vips copy input.svs[level=2] output.tif

4. Use with VoltRon:
   xenium <- addXeniumHE(xenium, 'output.tif')

--------------------------------------------------------------------------------
METHOD 4: Using Python + OpenSlide (For programmatic conversion)
--------------------------------------------------------------------------------

1. Install OpenSlide Python:
   pip install openslide-python Pillow

2. Create a conversion script (save as convert_svs.py):

   from openslide import OpenSlide
   from PIL import Image

   # Open SVS
   slide = OpenSlide('input.svs')

   # Get a specific resolution level (0 = highest)
   level = 2  # Mid-resolution
   dims = slide.level_dimensions[level]

   # Read region
   img = slide.read_region((0, 0), level, dims)

   # Convert RGBA to RGB
   img = img.convert('RGB')

   # Save as TIFF
   img.save('output.tif', 'TIFF')

3. Run the script:
   python convert_svs.py

4. Use with VoltRon:
   xenium <- addXeniumHE(xenium, 'output.tif')

--------------------------------------------------------------------------------
METHOD 5: Using R with Alternative Approach
--------------------------------------------------------------------------------

If you can read the SVS in Python but not R, use this workflow:

# In Python (with openslide):
from openslide import OpenSlide
slide = OpenSlide('input.svs')
level = 2
dims = slide.level_dimensions[level]
img = slide.read_region((0, 0), level, dims).convert('RGB')
img.save('converted.tif')

# Then in R:
xenium <- addXeniumHE(xenium, 'converted.tif')

--------------------------------------------------------------------------------
CHOOSING THE RIGHT RESOLUTION LEVEL
--------------------------------------------------------------------------------

When converting, you can choose different resolution levels:

Level 0 (Highest) : ~40,000 × 30,000 pixels
  - Use for small files (<5 GB)
  - Maximum detail
  - Slow alignment

Level 1-2 (Mid)   : ~10,000 × 7,500 pixels
  - RECOMMENDED for alignment
  - Good balance
  - Works for most files

Level 3-4 (Lower) : ~5,000 × 3,750 pixels
  - Use for large files (>10 GB)
  - Fast alignment
  - Good enough quality

--------------------------------------------------------------------------------
TROUBLESHOOTING
--------------------------------------------------------------------------------

Q: Conversion is very slow
A: Use a lower resolution level (level 2-3 instead of 0-1)

Q: Output file is huge (>2 GB)
A: Use lower resolution or compress: vips copy input.svs[level=2] output.tif[compression=jpeg,Q=90]

Q: Image quality is poor
A: Use higher resolution level or increase JPEG quality

Q: Getting 'out of memory' errors
A: Use lower resolution level or increase system RAM

--------------------------------------------------------------------------------
RECOMMENDED WORKFLOW FOR XENIUM H&E ALIGNMENT
--------------------------------------------------------------------------------

1. Convert SVS at level 2 (mid-resolution):
   - QuPath: Export at full resolution
   - vips: vips copy input.svs[level=2] output.tif
   - Python: level = 2 in the script

2. Use converted TIFF with VoltRon:
   xenium <- addXeniumHE(xenium, 'output.tif')

3. If alignment is poor, try level 1 (higher resolution)

4. If alignment is slow, try level 3 (lower resolution)

================================================================================

For more help, see:
- ?diagnoseSVS - Diagnose why SVS file won't load
- VoltRon documentation on image formats

================================================================================
")
}


#' Create SVS Conversion Script
#'
#' Generate a Python script for converting SVS to TIFF using OpenSlide
#'
#' @param output_file Path where to save the Python script (default: 'convert_svs.py')
#' @param level Resolution level to extract (default: 2)
#'
#' @examples
#' \dontrun{
#' # Create conversion script
#' createSVSConversionScript()
#'
#' # Then run in terminal:
#' # python convert_svs.py input.svs output.tif
#' }
#'
#' @export
createSVSConversionScript <- function(output_file = "convert_svs.py", level = 2) {
  script <- sprintf('#!/usr/bin/env python3
"""
SVS to TIFF Converter using OpenSlide
Generated by VoltRon

Usage:
    python %s input.svs output.tif [level]

Arguments:
    input.svs  : Path to input SVS file
    output.tif : Path to output TIFF file
    level      : Resolution level (default: %d, 0=highest resolution)

Installation:
    pip install openslide-python Pillow
"""

import sys
from openslide import OpenSlide
from PIL import Image

def convert_svs_to_tiff(input_path, output_path, level=%d):
    """Convert SVS to TIFF at specified resolution level"""

    print(f"Opening SVS file: {input_path}")
    slide = OpenSlide(input_path)

    # Print available levels
    print(f"Available resolution levels: {slide.level_count}")
    for i in range(slide.level_count):
        dims = slide.level_dimensions[i]
        downsample = slide.level_downsamples[i]
        print(f"  Level {i}: {dims[0]} x {dims[1]} (downsample: {downsample:.2f}x)")

    # Check if level is valid
    if level >= slide.level_count:
        print(f"Warning: Level {level} not available, using level {slide.level_count-1}")
        level = slide.level_count - 1

    # Get dimensions for the selected level
    dims = slide.level_dimensions[level]
    print(f"\\nExtracting level {level}: {dims[0]} x {dims[1]}")

    # Read the entire region at the specified level
    img = slide.read_region((0, 0), level, dims)

    # Convert RGBA to RGB (remove alpha channel)
    print("Converting to RGB...")
    img = img.convert("RGB")

    # Save as TIFF
    print(f"Saving to: {output_path}")
    img.save(output_path, "TIFF", compression="jpeg", quality=95)

    print(f"✓ Conversion complete!")
    print(f"  Input:  {input_path}")
    print(f"  Output: {output_path}")
    print(f"  Level:  {level}")
    print(f"  Size:   {dims[0]} x {dims[1]}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    input_svs = sys.argv[1]
    output_tif = sys.argv[2]
    level = int(sys.argv[3]) if len(sys.argv) > 3 else %d

    convert_svs_to_tiff(input_svs, output_tif, level)
', output_file, level, level, level)

  writeLines(script, output_file)
  message("Created Python conversion script: ", output_file)
  message("\nUsage:")
  message("  python ", output_file, " input.svs output.tif [level]")
  message("\nExample:")
  message("  python ", output_file, " my_he_image.svs converted.tif 2")
  message("\nRequirements:")
  message("  pip install openslide-python Pillow")

  invisible(output_file)
}
