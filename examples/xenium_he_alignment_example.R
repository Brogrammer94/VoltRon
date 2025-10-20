################################################################################
# VoltRon: Automated Xenium H&E Alignment Example
################################################################################
#
# This script demonstrates the automated workflow for aligning post-Xenium H&E
# images to Xenium DAPI immunofluorescence data using the addXeniumHE() function.
#
# Author: VoltRon Team
# Date: 2025
#
################################################################################

# Load required libraries
library(VoltRon)

################################################################################
# Example 1: Basic Automated Alignment
################################################################################

# Import Xenium data
xenium <- importXenium(
  "path/to/xenium/outs",
  sample_name = "Sample1"
)

# Add H&E image with automated alignment (one simple step!)
xenium <- addXeniumHE(
  xenium,
  he_image_path = "path/to/post_xenium_he_image.tif",
  channel_name = "H&E",
  verbose = TRUE
)

# View the aligned H&E
vrImages(xenium, channel = "H&E")

# Visualize gene expression on H&E background
vrSpatialFeaturePlot(
  xenium,
  features = c("ERBB2", "ESR1", "PGR"),
  channel = "H&E"
)

################################################################################
# Example 2: Advanced Alignment with Custom Parameters
################################################################################

# For challenging alignments, you can tune the parameters
xenium <- addXeniumHE(
  xenium,
  he_image_path = "path/to/he_image.tif",
  channel_name = "H&E",

  # Feature detection parameters
  MAX_FEATURES = 1000,           # Increase for more keypoints
  GOOD_MATCH_PERCENT = 0.20,     # Increase for stricter matching

  # Matching algorithm
  matcher = "BRUTE-FORCE",        # More accurate than FLANN

  # Transformation method
  method = "Homography+Non-Rigid", # Handle non-rigid deformations

  # Image preprocessing
  invert_dapi = TRUE,             # Negate DAPI (recommended)
  scale_he = 1.0,                 # Scale H&E if needed
  scale_dapi = 1.0,               # Scale DAPI if needed

  # Rotation/flipping if images are misaligned
  rotate_dapi = "0",              # Options: "0", "90", "180", "270"
  flipflop_dapi = "None",         # Options: "None", "Horizontal", "Vertical"

  verbose = TRUE
)

################################################################################
# Example 3: Reproducible Analysis with Saved Parameters
################################################################################

# Create and save parameter set for reproducible alignment
he_params <- getXeniumHEParams(
  MAX_FEATURES = 800,
  GOOD_MATCH_PERCENT = 0.18,
  matcher = "FLANN",
  method = "Homography",
  invert_dapi = TRUE
)

# Save parameters for later use
saveRDS(he_params, "he_alignment_params.rds")

# Apply same parameters to multiple samples
xenium_samples <- c("Sample1", "Sample2", "Sample3")
he_images <- c("sample1_he.tif", "sample2_he.tif", "sample3_he.tif")

aligned_objects <- list()
for (i in seq_along(xenium_samples)) {
  # Import Xenium
  xen <- importXenium(
    paste0("path/to/", xenium_samples[i], "/outs"),
    sample_name = xenium_samples[i]
  )

  # Apply saved parameters
  xen <- do.call(addXeniumHE, c(
    list(xen, he_images[i]),
    he_params
  ))

  aligned_objects[[xenium_samples[i]]] <- xen
}

################################################################################
# Example 4: Troubleshooting Failed Alignments
################################################################################

# If alignment fails, try these strategies:

# Strategy 1: Increase feature count
xenium <- addXeniumHE(
  xenium,
  "he_image.tif",
  MAX_FEATURES = 2000,  # Detect more keypoints
  verbose = TRUE
)

# Strategy 2: Use different matcher
xenium <- addXeniumHE(
  xenium,
  "he_image.tif",
  matcher = "BRUTE-FORCE",  # More accurate but slower
  verbose = TRUE
)

# Strategy 3: Adjust image orientations
xenium <- addXeniumHE(
  xenium,
  "he_image.tif",
  rotate_dapi = "180",       # Rotate if images are flipped
  flipflop_dapi = "Horizontal",  # Flip if needed
  verbose = TRUE
)

# Strategy 4: Try non-rigid transformation for tissue deformation
xenium <- addXeniumHE(
  xenium,
  "he_image.tif",
  method = "Homography+Non-Rigid",
  verbose = TRUE
)

# If automated alignment still fails, use the interactive workflow:
# See ?registerSpatialData for manual alignment via Shiny interface

################################################################################
# Example 5: Working with Multiple Channels
################################################################################

# Check all available channels
vrImageChannelNames(xenium)

# You can add multiple H&E variants with different parameters
xenium <- addXeniumHE(xenium, "he_highres.tif", channel_name = "HE_highres")
xenium <- addXeniumHE(xenium, "he_lowres.tif", channel_name = "HE_lowres")

# Switch between channels in visualization
vrSpatialFeaturePlot(xenium, features = "ERBB2", channel = "DAPI")
vrSpatialFeaturePlot(xenium, features = "ERBB2", channel = "HE_highres")

################################################################################
# Tips for Best Results
################################################################################
#
# 1. DAPI Inversion: Always use invert_dapi = TRUE (default) when aligning
#    DAPI fluorescence to H&E histology
#
# 2. Feature Count: Start with MAX_FEATURES = 500-1000. Increase if alignment
#    quality is poor.
#
# 3. Match Quality: GOOD_MATCH_PERCENT = 0.15-0.25 works well for most cases
#
# 4. Matcher Choice:
#    - FLANN: Fast, approximate matching (default, works for most cases)
#    - BRUTE-FORCE: Slower but more accurate (use for challenging alignments)
#
# 5. Transformation Methods:
#    - "Homography": Perspective transformation (fastest, works for flat tissue)
#    - "Homography+Non-Rigid": Handles tissue deformation (recommended)
#    - "Affine+Non-Rigid": Alternative for deformed tissue
#    - "Non-Rigid": Thin-plate spline (most flexible)
#
# 6. Image Quality: Higher resolution images generally produce better alignment
#
# 7. Preprocessing: Adjust brightness/contrast of images before alignment if
#    they differ significantly: modulateImage(xenium, brightness = 800)
#
################################################################################
