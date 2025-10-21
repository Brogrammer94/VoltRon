####
# Automated Xenium H&E Alignment ####
####

#' Add H&E Image to Xenium Data with Automated Alignment
#'
#' This function automates the process of aligning a post-Xenium H&E image to
#' Xenium DAPI immunofluorescence data and adding it as a new image channel.
#' The alignment uses automated feature detection (SIFT) and matching (FLANN or
#' BRUTE-FORCE) via OpenCV embedded in VoltRon.
#'
#' @param xenium_object A VoltRon object containing Xenium data with DAPI image
#' @param he_image_path Path to the H&E image file. Supports multiple formats:
#'   TIFF, PNG, JPEG, SVS (Aperio), and other formats supported by ImageMagick
#'   or Bio-Formats.
#' @param assay_name Name of the Xenium assay to add H&E channel to. If NULL,
#'   uses the first assay.
#' @param svs_resolution Resolution level for SVS/pyramidal images (default: NULL,
#'   auto-selects). Lower numbers = higher resolution. Use 1-3 for typical alignment.
#' @param channel_name Name for the new H&E channel (default: "H&E")
#' @param image_name Name of the spatial/image system (default: "main")
#' @param invert_dapi Whether to invert/negate the DAPI image for better
#'   alignment with H&E (default: TRUE, recommended)
#' @param GOOD_MATCH_PERCENT Percentage of good feature matches to use
#'   (default: 0.15, range: 0-1)
#' @param MAX_FEATURES Maximum number of features to detect in each image
#'   (default: 500)
#' @param matcher Matching algorithm: "FLANN" (fast, approximate) or
#'   "BRUTE-FORCE" (slower, exact) (default: "FLANN")
#' @param method Transformation method: "Homography", "Homography+Non-Rigid",
#'   "Affine+Non-Rigid", or "Non-Rigid" (default: "Homography")
#' @param scale_he Scale factor for H&E image resolution (default: 1.0)
#' @param scale_dapi Scale factor for DAPI image resolution (default: 1.0)
#' @param rotate_dapi Rotation to apply to DAPI: "0", "90", "180", "270"
#'   (default: "0")
#' @param rotate_he Rotation to apply to H&E: "0", "90", "180", "270"
#'   (default: "0")
#' @param flipflop_dapi Flip operation for DAPI: "None", "Horizontal",
#'   "Vertical" (default: "None")
#' @param flipflop_he Flip operation for H&E: "None", "Horizontal", "Vertical"
#'   (default: "None")
#' @param verbose Whether to print progress messages (default: TRUE)
#'
#' @return A VoltRon object with the aligned H&E image added as a new channel
#'
#' @details
#' This function simplifies the workflow described in the VoltRon registration
#' documentation. Instead of:
#' \enumerate{
#'   \item Importing H&E as a separate VoltRon object
#'   \item Using the interactive Shiny app for registration
#'   \item Manually extracting and assigning the registered image
#' }
#'
#' You can now simply call:
#' \preformatted{
#'   xenium <- addXeniumHE(xenium, "path/to/he_image.tif")
#' }
#'
#' The function automatically:
#' \itemize{
#'   \item Loads the H&E image
#'   \item Extracts the DAPI channel from Xenium data
#'   \item Performs automated feature-based registration
#'   \item Warps the H&E image to align with Xenium coordinates
#'   \item Adds the aligned H&E as a new channel
#' }
#'
#' **Note:** DAPI images are typically inverted (negated) to align better with
#' H&E histology images. This is controlled by \code{invert_dapi = TRUE}.
#'
#' **SVS Support:** The function automatically detects and handles SVS (Aperio)
#' whole slide imaging files. SVS files are multi-resolution pyramidal images:
#' \itemize{
#'   \item Resolution levels are auto-selected (typically level 2-3 for alignment)
#'   \item Use \code{svs_resolution} parameter to manually select a level
#'   \item Lower resolution numbers = higher image quality (but slower alignment)
#'   \item Requires RBioFormats: \code{BiocManager::install('RBioFormats')}
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage - automated alignment with defaults
#' library(VoltRon)
#' xenium <- importXenium("Xenium_R1/outs", sample_name = "Sample1")
#' xenium <- addXeniumHE(xenium, "post_xenium_he_image.tif")
#'
#' # SVS format support (whole slide images)
#' xenium <- addXeniumHE(xenium, "post_xenium_he_image.svs")
#'
#' # SVS with manual resolution selection
#' xenium <- addXeniumHE(
#'   xenium,
#'   "post_xenium_he_image.svs",
#'   svs_resolution = 2  # Level 2 (mid-resolution)
#' )
#'
#' # View the aligned H&E
#' vrImages(xenium, channel = "H&E")
#'
#' # Advanced usage - customize alignment parameters
#' xenium <- addXeniumHE(
#'   xenium,
#'   "post_xenium_he_image.tif",
#'   channel_name = "HE",
#'   MAX_FEATURES = 1000,
#'   GOOD_MATCH_PERCENT = 0.20,
#'   matcher = "BRUTE-FORCE",
#'   method = "Homography+Non-Rigid"
#' )
#'
#' # Visualize spatial features with H&E background
#' vrSpatialFeaturePlot(xenium, features = "ERBB2", channel = "H&E")
#' }
#'
#' @seealso
#' \code{\link{importXenium}}, \code{\link{registerSpatialData}},
#' \code{\link{vrImages}}
#'
#' @importFrom magick image_read image_info image_scale geometry_size_percent
#' @importFrom EBImage as.Image
#' @importFrom grDevices as.raster
#'
#' @export
addXeniumHE <- function(
  xenium_object,
  he_image_path,
  assay_name = NULL,
  svs_resolution = NULL,
  channel_name = "H&E",
  image_name = "main",
  invert_dapi = TRUE,
  GOOD_MATCH_PERCENT = 0.15,
  MAX_FEATURES = 500,
  matcher = "FLANN",
  method = "Homography",
  scale_he = 1.0,
  scale_dapi = 1.0,
  rotate_dapi = "0",
  rotate_he = "0",
  flipflop_dapi = "None",
  flipflop_he = "None",
  verbose = TRUE
) {
  # Validate inputs
  if (!inherits(xenium_object, "VoltRon")) {
    stop("xenium_object must be a VoltRon object")
  }
  if (!file.exists(he_image_path)) {
    stop("H&E image file not found: ", he_image_path)
  }

  # Check file format
  is_svs <- grepl("\\.(svs|SVS)$", he_image_path)
  is_ome_tiff <- grepl("\\.(ome\\.tiff|ome\\.tif)$", he_image_path)

  # Get assay name
  if (is.null(assay_name)) {
    assay_name <- vrAssayNames(xenium_object)[1]
    if (verbose) {
      message("Using assay: ", assay_name)
    }
  }

  # Step 1: Load H&E image
  if (verbose) {
    message("Loading H&E image from: ", he_image_path)
    if (is_svs) {
      message("  Detected SVS format (whole slide image)")
    } else if (is_ome_tiff) {
      message("  Detected OME-TIFF format (pyramidal image)")
    }
  }

  # Load image based on format
  if (is_svs || is_ome_tiff) {
    # SVS and OME-TIFF files require RBioFormats
    if (!requireNamespace('RBioFormats', quietly = TRUE)) {
      stop(
        "SVS and OME-TIFF formats require the RBioFormats package.\n",
        "Install it with: BiocManager::install('RBioFormats')\n\n",
        "Alternative: Convert SVS to TIFF first. See: ?convertSVSWorkflow"
      )
    }

    # Try to read metadata
    if (verbose) {
      message("  Reading image metadata...")
    }

    meta <- tryCatch({
      RBioFormats::read.metadata(he_image_path)
    }, error = function(e) {
      # RBioFormats failed - provide helpful error message
      stop(
        "\n========================================\n",
        "Failed to read SVS/OME-TIFF file with RBioFormats.\n",
        "========================================\n\n",
        "This can happen if:\n",
        "1. The SVS file is corrupted or uses an unsupported variant\n",
        "2. Bio-Formats cannot parse this specific file format\n",
        "3. The file was created with an incompatible scanner\n\n",
        "SOLUTION: Convert the SVS file to TIFF first.\n\n",
        "Quick conversion methods:\n",
        "  • QuPath (easiest): File → Export images → TIFF\n",
        "  • ImageJ/FIJI: File → Open → Save As TIFF\n",
        "  • Command-line (vips): vips copy input.svs output.tif\n",
        "  • Python script: createSVSConversionScript()\n\n",
        "For detailed instructions, run:\n",
        "  convertSVSWorkflow()\n\n",
        "After conversion, use the TIFF file:\n",
        "  xenium <- addXeniumHE(xenium, 'converted_image.tif')\n\n",
        "Original error: ", conditionMessage(e), "\n"
      )
    })

    # Auto-select resolution if not specified
    if (is.null(svs_resolution)) {
      # Get number of available resolutions
      n_resolutions <- meta$resolutionCount

      if (verbose) {
        message("  Available resolution levels: ", n_resolutions)
        for (i in 1:n_resolutions) {
          res_meta <- RBioFormats::read.metadata(he_image_path)
          width <- res_meta$sizeX[i]
          height <- res_meta$sizeY[i]
          message("    Level ", i, ": ", width, " x ", height)
        }
      }

      # Auto-select: use mid-resolution for alignment (good balance)
      # For SVS files: Level 1 is usually full res, level 2-3 are good for alignment
      if (n_resolutions >= 3) {
        svs_resolution <- 2  # Mid-resolution
      } else if (n_resolutions == 2) {
        svs_resolution <- 2  # Lower resolution
      } else {
        svs_resolution <- 1  # Only one resolution available
      }

      if (verbose) {
        message("  Auto-selected resolution level: ", svs_resolution)
        message("  (Use svs_resolution parameter to manually specify)")
      }
    } else {
      if (verbose) {
        message("  Using specified resolution level: ", svs_resolution)
      }
    }

    # Read the image at the specified resolution
    if (verbose) {
      message("  Reading image at resolution level ", svs_resolution, "...")
    }

    img <- tryCatch({
      RBioFormats::read.image(
        he_image_path,
        series = 1,
        resolution = svs_resolution,
        normalize = TRUE
      )
    }, error = function(e) {
      stop(
        "\n========================================\n",
        "Failed to read image data from SVS/OME-TIFF file.\n",
        "========================================\n\n",
        "Error occurred while reading resolution level ", svs_resolution, ".\n\n",
        "Try:\n",
        "1. Use a different resolution level (try svs_resolution = 1 or 3)\n",
        "2. Convert the SVS to TIFF format (see ?convertSVSWorkflow)\n",
        "3. Check if the file is corrupted\n\n",
        "Original error: ", conditionMessage(e), "\n"
      )
    })

    # Convert to magick image
    img <- EBImage::as.Image(img)

    # Check if RGB
    if (length(d <- dim(img)) > 2 && d[3] == 3) {
      # RGB image
      he_image <- magick::image_read(grDevices::as.raster(img))
    } else {
      # Grayscale - convert to RGB
      img <- img / max(img)
      he_image <- magick::image_read(grDevices::as.raster(img))
    }

    if (verbose) {
      img_info <- magick::image_info(he_image)
      message("  Loaded image: ", img_info$width, " x ", img_info$height)
    }

  } else {
    # Standard formats (TIFF, PNG, JPEG, etc.) - use magick directly
    he_image <- magick::image_read(he_image_path)

    if (verbose) {
      img_info <- magick::image_info(he_image)
      message("  Loaded image: ", img_info$width, " x ", img_info$height)
    }
  }

  # Step 2: Extract DAPI image from Xenium object
  if (verbose) {
    message("Extracting DAPI image from Xenium data")
  }
  assay <- xenium_object[[assay_name]]
  channel_names <- vrImageChannelNames(assay)

  # Get the main channel (typically DAPI)
  main_channel <- vrMainChannel(assay)
  dapi_image <- vrImages(assay, channel = main_channel, as.raster = TRUE)

  if (!inherits(dapi_image, "magick-image")) {
    dapi_image <- magick::image_read(dapi_image)
  }

  if (verbose) {
    message("Using channel: ", main_channel, " as reference")
  }

  # Step 3: Apply scaling if needed
  if (scale_he != 1.0) {
    if (verbose) {
      message("Scaling H&E image by factor: ", scale_he)
    }
    he_image <- magick::image_scale(
      he_image,
      magick::geometry_size_percent(100 * scale_he)
    )
  }

  if (scale_dapi != 1.0) {
    if (verbose) {
      message("Scaling DAPI image by factor: ", scale_dapi)
    }
    dapi_image <- magick::image_scale(
      dapi_image,
      magick::geometry_size_percent(100 * scale_dapi)
    )
  }

  # Step 4: Perform automated registration
  if (verbose) {
    message("Performing automated registration using ", matcher, " with ", method)
    message("  Max features: ", MAX_FEATURES)
    message("  Match threshold: ", GOOD_MATCH_PERCENT)
    message("  Invert DAPI: ", invert_dapi)
  }

  reg_result <- getRcppAutomatedRegistration(
    ref_image = dapi_image,
    query_image = he_image,
    GOOD_MATCH_PERCENT = GOOD_MATCH_PERCENT,
    MAX_FEATURES = MAX_FEATURES,
    invert_query = FALSE,  # H&E is query, don't invert
    invert_ref = invert_dapi,  # DAPI is reference, invert to match H&E
    flipflop_query = flipflop_he,
    flipflop_ref = flipflop_dapi,
    rotate_query = rotate_he,
    rotate_ref = rotate_dapi,
    matcher = matcher,
    method = method
  )

  # Check if registration was successful
  if (is.na(reg_result$aligned_image)) {
    stop(
      "Automated registration failed. Try adjusting parameters:\n",
      "  - Increase MAX_FEATURES (current: ", MAX_FEATURES, ")\n",
      "  - Adjust GOOD_MATCH_PERCENT (current: ", GOOD_MATCH_PERCENT, ")\n",
      "  - Try different matcher: ", ifelse(matcher == "FLANN", "BRUTE-FORCE", "FLANN"), "\n",
      "  - Try different method (e.g., 'Homography+Non-Rigid')\n",
      "  - Check image orientations (rotate_dapi, rotate_he, flipflop_*)"
    )
  }

  if (verbose) {
    message("Registration successful!")
  }

  # Step 5: Get the aligned H&E image
  he_aligned <- reg_result$aligned_image

  # Step 6: Add H&E as a new channel to the existing assay
  if (verbose) {
    message("Adding H&E channel to assay: ", assay_name)
  }

  # Get the spatial object
  spatial_obj <- assay@spatial[[image_name]]

  # Check if channel already exists
  existing_channels <- names(spatial_obj@image)
  if (channel_name %in% existing_channels) {
    warning("Channel '", channel_name, "' already exists and will be replaced")
  }

  # Add the new channel
  vrImages(xenium_object[[assay_name]], name = image_name, channel = channel_name) <-
    he_aligned

  if (verbose) {
    message("H&E channel '", channel_name, "' successfully added!")
    message("\nYou can now view it with:")
    message("  vrImages(object, channel = '", channel_name, "')")
    message("Or use it in spatial plots:")
    message("  vrSpatialFeaturePlot(object, features = 'GENE', channel = '", channel_name, "')")
  }

  # Return the updated object
  return(xenium_object)
}


#' Get Xenium H&E Alignment Parameters
#'
#' Helper function to create a parameter list for \code{addXeniumHE} that can
#' be saved and reused for reproducible alignment.
#'
#' @param GOOD_MATCH_PERCENT Percentage of good feature matches
#' @param MAX_FEATURES Maximum number of features to detect
#' @param matcher Matching algorithm: "FLANN" or "BRUTE-FORCE"
#' @param method Transformation method
#' @param ... Additional parameters for \code{addXeniumHE}
#'
#' @return A named list of parameters
#'
#' @examples
#' \dontrun{
#' # Create parameter set
#' params <- getXeniumHEParams(
#'   MAX_FEATURES = 1000,
#'   GOOD_MATCH_PERCENT = 0.20,
#'   matcher = "BRUTE-FORCE"
#' )
#'
#' # Save for later use
#' saveRDS(params, "he_alignment_params.rds")
#'
#' # Reuse parameters
#' params <- readRDS("he_alignment_params.rds")
#' xenium <- do.call(addXeniumHE, c(list(xenium, "he_image.tif"), params))
#' }
#'
#' @export
getXeniumHEParams <- function(
  GOOD_MATCH_PERCENT = 0.15,
  MAX_FEATURES = 500,
  matcher = "FLANN",
  method = "Homography",
  ...
) {
  params <- list(
    GOOD_MATCH_PERCENT = GOOD_MATCH_PERCENT,
    MAX_FEATURES = MAX_FEATURES,
    matcher = matcher,
    method = method,
    ...
  )
  return(params)
}
