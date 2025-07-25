# Plotting utility functions for Flow Cytometry Analysis

# ============================================================================
# COLOR PALETTE HELPER FUNCTIONS
# ============================================================================

# Helper function to get viridis color scale for continuous data
getViridisColorScale <- function(color_palette, name, option_type = "color") {
  # Default to plasma if unrecognized palette
  option <- switch(color_palette,
                   "plasma" = "plasma",
                   "viridis" = "viridis", 
                   "magma" = "magma",
                   "inferno" = "inferno",
                   "plasma")  # default
  
  if (option_type == "color") {
    return(scale_color_viridis_c(name = name, option = option))
  } else if (option_type == "fill") {
    return(scale_fill_viridis_c(name = name, option = option))
  } else if (option_type == "fill_discrete") {
    return(scale_fill_viridis_d(name = name, option = option))
  }
}

# Helper function to apply color palette to a ggplot object
applyColorPalette <- function(plot_obj, color_palette, marker_name, scale_type = "color") {
  if (scale_type == "color") {
    return(plot_obj + getViridisColorScale(color_palette, marker_name, "color"))
  } else if (scale_type == "fill") {
    return(plot_obj + getViridisColorScale(color_palette, marker_name, "fill"))
  } else if (scale_type == "both") {
    # For contour plots that need both color and fill
    return(plot_obj + 
           getViridisColorScale(color_palette, paste(marker_name, "Points"), "color") +
           getViridisColorScale(color_palette, paste(marker_name, "Level"), "fill_discrete"))
  }
}

# ============================================================================
# MAIN PLOTTING FUNCTIONS
# ============================================================================

# Function to create a dimensionality reduction plot with ggplot2
createDimReductionPlot <- function(plot_data, dim1, dim2, colorBy = NULL, 
                                   color_palette = "viridis", point_size = 3, font_size = 12,
                                   title = NULL, xlab = NULL, ylab = NULL) {
  
  # Set default axis labels if not provided
  if (is.null(xlab)) xlab <- dim1
  if (is.null(ylab)) ylab <- dim2
  
  # Create plot based on coloring variable
  if (!is.null(colorBy) && colorBy != "None" && colorBy != "Cluster" && 
      colorBy %in% colnames(plot_data)) {
    # Color by numeric marker expression
    p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]])) +
      geom_point(aes(color = .data[[colorBy]]), alpha = 0.7, size = point_size/2) +
      scale_color_viridis_c(name = colorBy) +
      labs(title = title, x = xlab, y = ylab)
  } 
  else if (!is.null(colorBy) && colorBy == "Cluster" && "Cluster" %in% colnames(plot_data)) {
    # Color by cluster
    p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]])) +
      geom_point(aes(color = Cluster), alpha = 0.7, size = point_size/2) +
      labs(title = title, x = xlab, y = ylab, color = "Cluster")
    
    # Apply appropriate color palette
    if (color_palette == "viridis") {
      p <- p + scale_color_viridis_d()
    } else if (color_palette == "plasma") {
      p <- p + scale_color_viridis_d(option = "plasma")
    } else if (color_palette == "magma") {
      p <- p + scale_color_viridis_d(option = "magma")
    } else if (color_palette == "inferno") {
      p <- p + scale_color_viridis_d(option = "inferno")
    } else if (color_palette == "blues") {
      p <- p + scale_color_brewer(palette = "Blues")
    } else if (color_palette == "reds") {
      p <- p + scale_color_brewer(palette = "Reds")
    } else if (color_palette == "brewer_paired") {
      p <- p + scale_color_brewer(palette = "Paired")
    } else if (color_palette == "brewer_brbg") {
      p <- p + scale_color_brewer(palette = "BrBG")
    }
  }
  else {
    # No coloring
    p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]])) +
      geom_point(alpha = 0.7, size = point_size/2, color = "#3366CC") +
      labs(title = title, x = xlab, y = ylab)
  }
  
  # Apply enhanced theme with better font control
  p <- p + theme_minimal(base_size = font_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = font_size * 1.2),
      plot.subtitle = element_text(hjust = 0.5, size = font_size * 1.0),
      axis.title = element_text(face = "bold", size = font_size * 1.1),
      axis.text = element_text(size = font_size),
      legend.title = element_text(face = "bold", size = font_size * 1.1),
      legend.text = element_text(size = font_size),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(color = "grey80", fill = NA)
    ) +
    # Add fixed coordinate ratio to ensure proper aspect ratio
    coord_fixed(ratio = 1)
  
  return(p)
}

# Function to convert ggplot to plotly with standard settings
convertToPlotly <- function(ggplot_obj, width = 800, height = 600, font_size = 12) {
  p <- ggplotly(ggplot_obj, width = width, height = height) %>%
    layout(
      hoverlabel = list(
        bgcolor = "white",
        font = list(family = "Arial", size = font_size)
      ),
      margin = list(l = 50, r = 50, b = 50, t = 50)
    )
  
  return(p)
}

# Function to create a heatmap of cluster expression profiles
createClusterHeatmap <- function(centers, method = "Hierarchical", 
                                 title = "Cluster Expression Profiles",
                                 font_size = 12, cluster_rows = TRUE,
                                 population_data = NULL) {
  
  # Convert matrix to data frame for ggplot
  centers_df <- as.data.frame(centers) %>%
    tibble::rownames_to_column("Cluster") %>%
    reshape2::melt(id.vars = "Cluster", variable.name = "Marker", value.name = "Expression")
  
  # If population data is available, use it to modify cluster labels
  if (!is.null(population_data) && "Population" %in% colnames(population_data)) {
    # Create a mapping from cluster to population
    pop_mapping <- setNames(
      population_data$Population,
      as.character(population_data$Cluster)
    )
    
    # Add population labels to centers_df
    centers_df$ClusterLabel <- sapply(centers_df$Cluster, function(clust) {
      cluster_num <- gsub("Cluster ", "", clust)
      if (cluster_num %in% names(pop_mapping)) {
        paste0(clust, " (", pop_mapping[cluster_num], ")")
      } else {
        clust
      }
    })
  } else {
    # If no population data, use cluster as is
    centers_df$ClusterLabel <- centers_df$Cluster
  }
  
  # Create heatmap
  p <- ggplot(centers_df, aes(x = Marker, y = ClusterLabel, fill = Expression)) +
    geom_tile() +
    scale_fill_gradient2(low = "navy", mid = "white", high = "firebrick3") +
    labs(
      title = title,
      subtitle = paste("Clustering method:", method),
      x = "Markers", 
      y = "Clusters",
      fill = "Expression"
    ) +
    theme_minimal(base_size = font_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.text.y = element_text(face = "bold"),
      panel.grid = element_blank()
    )
  
  return(p)
}

# Function to create a cluster comparison heatmap between two samples
createClusterComparisonHeatmap <- function(control_centers, treated_centers, 
                                           control_pops = NULL, treated_pops = NULL,
                                           font_size = 12) {
  # Calculate similarity matrix
  similarity_matrix <- matrix(NA, 
                              nrow = nrow(control_centers), 
                              ncol = nrow(treated_centers))
  
  for (i in 1:nrow(control_centers)) {
    for (j in 1:nrow(treated_centers)) {
      # Calculate Euclidean distance between cluster centers
      dist_val <- sqrt(sum((control_centers[i,] - treated_centers[j,])^2))
      # Convert distance to similarity (invert)
      similarity_matrix[i,j] <- 1 / (1 + dist_val)
    }
  }
  
  # Set row/column names
  rownames(similarity_matrix) <- paste0("C", rownames(control_centers))
  colnames(similarity_matrix) <- paste0("T", rownames(treated_centers))
  
  # Add population labels if available
  if (!is.null(control_pops) && !is.null(treated_pops)) {
    # Get population mappings
    control_pop_map <- setNames(
      control_pops$Population,
      paste0("C", control_pops$Cluster)
    )
    
    treated_pop_map <- setNames(
      treated_pops$Population,
      paste0("T", treated_pops$Cluster)
    )
    
    # Update row/column names with population information
    rownames(similarity_matrix) <- paste0(rownames(similarity_matrix), " (", 
                                          control_pop_map[rownames(similarity_matrix)], ")")
    
    colnames(similarity_matrix) <- paste0(colnames(similarity_matrix), " (", 
                                          treated_pop_map[colnames(similarity_matrix)], ")")
  }
  
  # Convert to data frame for ggplot
  sim_df <- reshape2::melt(similarity_matrix, varnames = c("Control", "Treated"), 
                           value.name = "Similarity")
  
  # Create heatmap
  p <- ggplot(sim_df, aes(x = Treated, y = Control, fill = Similarity)) +
    geom_tile() +
    scale_fill_viridis_c() +
    theme_minimal(base_size = font_size) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = font_size * 0.8),
      axis.text.y = element_text(size = font_size * 0.8),
      axis.title = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(hjust = 0.5, size = font_size * 1.2)
    ) +
    labs(
      title = "Cluster Similarity Between Control and Treated Samples",
      fill = "Similarity"
    ) +
    geom_text(aes(label = sprintf("%.2f", Similarity)), size = font_size * 0.25)
  
  return(p)
}

# Function to create signature marker heatmap for comparing samples
createSignatureMarkerHeatmap <- function(control_centers, treated_centers, 
                                         markers, control_pops = NULL, treated_pops = NULL,
                                         font_size = 12, control_name = "Control", 
                                         treated_name = "Treated") {
  # Create combined centers data frame
  control_df <- as.data.frame(control_centers) %>%
    tibble::rownames_to_column("Cluster") %>%
    mutate(Sample = control_name, 
           ClusterID = paste0("C", Cluster))
  
  treated_df <- as.data.frame(treated_centers) %>%
    tibble::rownames_to_column("Cluster") %>%
    mutate(Sample = treated_name, 
           ClusterID = paste0("T", Cluster))
  
  # Combine data
  combined_centers <- bind_rows(control_df, treated_df)
  
  # Add population labels if available
  if (!is.null(control_pops) && !is.null(treated_pops)) {
    # Create mapping for control populations
    control_pop_map <- setNames(
      control_pops$Population,
      control_pops$Cluster
    )
    
    # Create mapping for treated populations
    treated_pop_map <- setNames(
      treated_pops$Population,
      treated_pops$Cluster
    )
    
    # Add population column
    combined_centers$Population <- NA
    for (i in 1:nrow(combined_centers)) {
      if (combined_centers$Sample[i] == control_name) {
        combined_centers$Population[i] <- control_pop_map[combined_centers$Cluster[i]]
      } else {
        combined_centers$Population[i] <- treated_pop_map[combined_centers$Cluster[i]]
      }
    }
    
    # Update ClusterID with population
    combined_centers$ClusterID <- paste0(combined_centers$ClusterID, " (", 
                                         combined_centers$Population, ")")
  }
  
  # Convert to long format
  # Determine which columns to exclude based on what exists
  cols_to_exclude <- "Cluster"
  if ("Population" %in% colnames(combined_centers)) {
    cols_to_exclude <- c(cols_to_exclude, "Population")
  }
  
  combined_long <- combined_centers %>%
    select(-all_of(cols_to_exclude)) %>%
    pivot_longer(cols = all_of(markers), names_to = "Marker", values_to = "Expression")
  
  # Scale expression values for heatmap
  combined_scaled <- combined_long %>%
    group_by(Marker) %>%
    mutate(Scaled_Expr = scale(Expression)[,1]) %>%
    ungroup()
  
  # Create the heatmap
  p <- ggplot(combined_scaled, aes(x = Marker, y = ClusterID, fill = Scaled_Expr)) +
    geom_tile() +
    scale_fill_gradient2(low = "navy", mid = "white", high = "firebrick3", midpoint = 0) +
    facet_grid(Sample ~ ., scales = "free_y", space = "free_y") +
    theme_minimal(base_size = font_size) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.text.y = element_text(),
      panel.grid = element_blank(),
      strip.text = element_text(face = "bold"),
      strip.background = element_rect(fill = "lightgray", color = NA),
      plot.title = element_text(hjust = 0.5)
    ) +
    labs(
      title = "Marker Expression Profiles by Cluster",
      x = "Marker",
      y = "Cluster",
      fill = "Z-score"
    )
  
  return(p)
}

# Function to create a boxplot of marker expression by cluster
createMarkerExpressionPlot <- function(plot_data, marker, color_palette = "viridis", 
                                       font_size = 12, include_violin = TRUE) {
  
  # Create base plot
  p <- ggplot(plot_data, aes(x = Cluster, y = .data[[marker]], fill = Cluster)) 
  
  # Add violin layer if requested
  if (include_violin) {
    p <- p + geom_violin(alpha = 0.7)
  }
  
  # Add boxplot layer
  p <- p + 
    geom_boxplot(width = 0.2, alpha = 0.7, outlier.shape = NA) +
    labs(
      title = paste("Distribution of", marker, "by Cluster"),
      x = "Cluster",
      y = marker
    ) +
    theme_minimal(base_size = font_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      axis.title = element_text(face = "bold"),
      legend.position = "none",
      panel.grid.minor = element_blank()
    )
  
  # Get the number of clusters to properly handle color palette expansion
  n_clusters <- length(unique(plot_data$Cluster))
  
  # Generate appropriate palette with enough colors
  if (color_palette == "viridis") {
    # Generate exactly as many colors as needed with viridis
    palette_colors <- viridis::viridis(n_clusters)
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "plasma") {
    # Generate exactly as many colors as needed with plasma
    palette_colors <- viridis::plasma(n_clusters)
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "magma") {
    # Generate exactly as many colors as needed with magma
    palette_colors <- viridis::magma(n_clusters)
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "inferno") {
    # Generate exactly as many colors as needed with inferno
    palette_colors <- viridis::inferno(n_clusters)
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "blues") {
    # Blues only has 9 colors max, so we need to handle expansion
    max_blues <- 9
    min_colors <- 3 # RColorBrewer requires minimum 3 colors
    
    if (n_clusters < min_colors) {
      # If fewer than minimum, get minimum then take what we need
      palette_colors <- RColorBrewer::brewer.pal(min_colors, "Blues")[1:n_clusters]
    } else if (n_clusters <= max_blues) {
      palette_colors <- RColorBrewer::brewer.pal(n_clusters, "Blues")
    } else {
      # Get max colors then recycle
      palette_colors <- RColorBrewer::brewer.pal(max_blues, "Blues")
      palette_colors <- rep_len(palette_colors, n_clusters)
    }
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "reds") {
    # Reds only has 9 colors max
    max_reds <- 9
    min_colors <- 3 # RColorBrewer requires minimum 3 colors
    
    if (n_clusters < min_colors) {
      palette_colors <- RColorBrewer::brewer.pal(min_colors, "Reds")[1:n_clusters]
    } else if (n_clusters <= max_reds) {
      palette_colors <- RColorBrewer::brewer.pal(n_clusters, "Reds")
    } else {
      palette_colors <- RColorBrewer::brewer.pal(max_reds, "Reds")
      palette_colors <- rep_len(palette_colors, n_clusters)
    }
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "brewer_paired") {
    # Paired has 12 colors max
    max_paired <- 12
    min_colors <- 3
    
    if (n_clusters < min_colors) {
      palette_colors <- RColorBrewer::brewer.pal(min_colors, "Paired")[1:n_clusters]
    } else if (n_clusters <= max_paired) {
      palette_colors <- RColorBrewer::brewer.pal(n_clusters, "Paired")
    } else {
      palette_colors <- RColorBrewer::brewer.pal(max_paired, "Paired")
      palette_colors <- rep_len(palette_colors, n_clusters)
    }
    p <- p + scale_fill_manual(values = palette_colors)
  } else if (color_palette == "brewer_brbg") {
    # BrBG has 11 colors max
    max_brbg <- 11
    min_colors <- 3
    
    if (n_clusters < min_colors) {
      palette_colors <- RColorBrewer::brewer.pal(min_colors, "BrBG")[1:n_clusters]
    } else if (n_clusters <= max_brbg) {
      palette_colors <- RColorBrewer::brewer.pal(n_clusters, "BrBG")
    } else {
      palette_colors <- RColorBrewer::brewer.pal(max_brbg, "BrBG")
      palette_colors <- rep_len(palette_colors, n_clusters)
    }
    p <- p + scale_fill_manual(values = palette_colors)
  } else {
    # Default to viridis if unrecognized palette
    palette_colors <- viridis::viridis(n_clusters)
    p <- p + scale_fill_manual(values = palette_colors)
  }
  
  return(p)
}

# Function to get a standardized theme with explicit font size handling
get_standard_theme <- function(font_size = 12) {
  theme_minimal(base_size = font_size) +
    theme(
      # Use !important to override any CSS from the browser
      plot.title = element_text(face = "bold", hjust = 0.5, size = font_size * 1.2),
      plot.subtitle = element_text(hjust = 0.5, size = font_size * 1.0),
      axis.title = element_text(face = "bold", size = font_size * 1.1),
      axis.text = element_text(size = font_size),
      legend.title = element_text(face = "bold", size = font_size * 1.1),
      legend.text = element_text(size = font_size),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(color = "grey80", fill = NA),
      # Ensure good spacing
      plot.margin = margin(t = 20, r = 20, b = 30, l = 20, unit = "pt")
    )
}

# Function to get the appropriate color scale based on palette name
get_color_palette <- function(palette_name) {
  switch(palette_name,
         "viridis" = scale_color_viridis_d(),
         "plasma" = scale_color_viridis_d(option = "plasma"),
         "magma" = scale_color_viridis_d(option = "magma"),
         "inferno" = scale_color_viridis_d(option = "inferno"),
         "blues" = scale_color_brewer(palette = "Blues"),
         "reds" = scale_color_brewer(palette = "Reds"),
         "brewer_paired" = scale_color_brewer(palette = "Paired"),
         "brewer_brbg" = scale_color_brewer(palette = "BrBG"),
         scale_color_viridis_d() # Default to viridis
  )
}

# Spillover compensation plotting functions

# Function to create spillover matrix heatmap
createSpilloverHeatmap <- function(spillover_matrix, title = "Spillover Matrix", font_size = 12) {
  # Convert matrix to long format for ggplot
  spillover_df <- as.data.frame(spillover_matrix)
  spillover_df$From <- rownames(spillover_df)
  spillover_long <- tidyr::pivot_longer(spillover_df, -From, names_to = "To", values_to = "Spillover")
  
  # Create the heatmap
  ggplot(spillover_long, aes(x = To, y = From, fill = Spillover)) +
    geom_tile(color = "white", size = 0.5) +
    geom_text(aes(label = round(Spillover, 3)), size = font_size/3, color = "black") +
    scale_fill_gradient2(
      low = "blue", 
      mid = "white", 
      high = "red", 
      midpoint = 0, 
      name = "Spillover\nCoefficient",
      limits = c(-1, 1)  # Standard range for spillover coefficients
    ) +
    theme_minimal(base_size = font_size) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
      axis.text.y = element_text(hjust = 1),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      panel.grid = element_blank(),
      axis.title = element_text(face = "bold")
    ) +
    labs(
      title = title,
      x = "From Channel (Spilling Into)",
      y = "To Channel (Receiving Spillover)"
    ) +
    coord_fixed()  # Keep squares square
}

# Function to create before/after compensation comparison
createCompensationComparisonPlot <- function(original_data, compensated_data, 
                                           channel1, channel2, 
                                           n_sample = 5000, font_size = 12) {
  # Sample data for faster plotting
  if (nrow(original_data) > n_sample) {
    sample_indices <- sample(nrow(original_data), n_sample)
    original_data <- original_data[sample_indices, ]
    compensated_data <- compensated_data[sample_indices, ]
  }
  
  # Create comparison data frame
  plot_data <- rbind(
    data.frame(
      x = original_data[, channel1],
      y = original_data[, channel2],
      Type = "Before Compensation"
    ),
    data.frame(
      x = compensated_data[, channel1],
      y = compensated_data[, channel2],
      Type = "After Compensation"
    )
  )
  
  # Create the plot
  ggplot(plot_data, aes(x = x, y = y)) +
    geom_point(alpha = 0.3, size = 0.5, color = "steelblue") +
    facet_wrap(~Type, ncol = 2) +
    theme_minimal(base_size = font_size) +
    theme(
      strip.text = element_text(size = font_size, face = "bold"),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.title = element_text(face = "bold")
    ) +
    labs(
      title = paste("Compensation Effect:", channel1, "vs", channel2),
      x = channel1, 
      y = channel2
    )
}

# ============================================================================
# MARKER EXPRESSION HEATMAP FUNCTIONS
# ============================================================================

# Function to create marker expression heatmap overlaid on dimensionality reduction
createMarkerExpressionHeatmap <- function(plot_data, marker, dim1 = "tsne1", dim2 = "tsne2", 
                                         method = "hex", bins = 50, 
                                         title = NULL, font_size = 12,
                                         color_palette = "plasma") {
  
  if (is.null(title)) {
    title <- paste(marker, "Expression Heatmap")
  }
  
  # Check if marker exists in data
  if (!marker %in% colnames(plot_data)) {
    stop(paste("Marker", marker, "not found in plot data"))
  }
  
  # Check if dimension columns exist
  if (!all(c(dim1, dim2) %in% colnames(plot_data))) {
    stop(paste("Dimension columns", dim1, "and/or", dim2, "not found in plot data"))
  }
  
  # Create heatmap based on method
  if (method == "hex") {
    # Hexagonal binning with marker expression as fill - with error handling
    
    # Check if we have valid data for binning
    marker_values <- plot_data[[marker]]
    valid_values <- marker_values[is.finite(marker_values)]
    
    if (length(valid_values) < 10) {
      # Not enough data for binning, fall back to scatter plot
      p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                 color = .data[[marker]])) +
        geom_point(alpha = 0.7, size = 0.8) +
        labs(title = paste(title, "(Scatter - insufficient data for binning)"), 
             x = dim1, y = dim2) +
        theme_minimal(base_size = font_size) +
        coord_fixed()
      
      # Apply color palette for scatter
      p <- applyColorPalette(p, color_palette, marker, "color")
      
    } else {
      # Sufficient data for binning
      tryCatch({
        p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                   z = .data[[marker]])) +
          stat_summary_hex(bins = bins, alpha = 0.8, fun = mean) +
          labs(title = title, x = dim1, y = dim2) +
          theme_minimal(base_size = font_size) +
          coord_fixed()
        
        # Apply color palette
        p <- applyColorPalette(p, color_palette, marker, "fill")
        
      }, error = function(e) {
        # If binning fails, fall back to scatter plot
        p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                   color = .data[[marker]])) +
          geom_point(alpha = 0.7, size = 0.8) +
          labs(title = paste(title, "(Scatter - binning failed)"), 
               x = dim1, y = dim2) +
          theme_minimal(base_size = font_size) +
          coord_fixed()
        
        # Apply color palette for scatter fallback
        p <- applyColorPalette(p, color_palette, marker, "color")
        
        return(p)
      })
    }
      
  } else if (method == "density2d") {
    # Density contours with marker expression as color
    p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]])) +
      geom_point(aes(color = .data[[marker]]), alpha = 0.6, size = 0.5) +
      stat_density_2d(alpha = 0.3, color = "white", linewidth = 0.8) +
      labs(title = title, x = dim1, y = dim2) +
      theme_minimal(base_size = font_size) +
      coord_fixed()
    
    # Apply color palette
    p <- applyColorPalette(p, color_palette, marker, "color")
      
  } else if (method == "contour") {
    # Filled contours based on marker expression - with error handling
    
    # Check if we have valid data for contours
    marker_values <- plot_data[[marker]]
    valid_values <- marker_values[is.finite(marker_values)]
    
    if (length(valid_values) < 10 || length(unique(valid_values)) < 3) {
      # Not enough variation for contours, fall back to scatter plot
      p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                 color = .data[[marker]])) +
        geom_point(alpha = 0.7, size = 0.8) +
        labs(title = paste(title, "(Scatter - insufficient data for contours)"), 
             x = dim1, y = dim2) +
        theme_minimal(base_size = font_size) +
        coord_fixed()
      
      # Apply color palette for scatter
      p <- applyColorPalette(p, color_palette, marker, "color")
      
    } else {
      # Sufficient data for contours
      tryCatch({
        p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                   z = .data[[marker]])) +
          geom_point(aes(color = .data[[marker]]), alpha = 0.4, size = 0.5) +
          stat_contour_filled(alpha = 0.6, bins = 15) +
          labs(title = title, x = dim1, y = dim2) +
          theme_minimal(base_size = font_size) +
          coord_fixed()
        
        # Apply color palettes
        p <- applyColorPalette(p, color_palette, marker, "both")
        
      }, error = function(e) {
        # If contour generation fails, fall back to scatter plot
        p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                                   color = .data[[marker]])) +
          geom_point(alpha = 0.7, size = 0.8) +
          labs(title = paste(title, "(Scatter - contour generation failed)"), 
               x = dim1, y = dim2) +
          theme_minimal(base_size = font_size) +
          coord_fixed()
        
        # Apply color palette for scatter fallback
        p <- applyColorPalette(p, color_palette, marker, "color")
        
        return(p)
      })
    }
    
  } else if (method == "scatter") {
    # Simple scatter plot with marker expression coloring
    p <- ggplot(plot_data, aes(x = .data[[dim1]], y = .data[[dim2]], 
                               color = .data[[marker]])) +
      geom_point(alpha = 0.7, size = 0.8) +
      labs(title = title, x = dim1, y = dim2) +
      theme_minimal(base_size = font_size) +
      coord_fixed()
    
    # Apply color palette
    p <- applyColorPalette(p, color_palette, marker, "color")
  }
  
  # Apply enhanced theme
  p <- p + theme_minimal(base_size = font_size) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = font_size * 1.2),
      axis.title = element_text(face = "bold", size = font_size * 1.1),
      axis.text = element_text(size = font_size),
      legend.title = element_text(face = "bold", size = font_size * 1.1),
      legend.text = element_text(size = font_size),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(color = "grey80", fill = NA)
    )
  
  return(p)
}

# Function to auto-detect available dimensionality reduction methods
getAvailableDimMethods <- function(plot_data) {
  methods <- list()
  
  if ("tsne1" %in% colnames(plot_data) && "tsne2" %in% colnames(plot_data)) {
    methods[["t-SNE"]] <- c("tsne1", "tsne2")
  }
  if ("umap1" %in% colnames(plot_data) && "umap2" %in% colnames(plot_data)) {
    methods[["UMAP"]] <- c("umap1", "umap2")
  }
  if ("pca1" %in% colnames(plot_data) && "pca2" %in% colnames(plot_data)) {
    methods[["PCA"]] <- c("pca1", "pca2")
  }
  if ("mds1" %in% colnames(plot_data) && "mds2" %in% colnames(plot_data)) {
    methods[["MDS"]] <- c("mds1", "mds2")
  }
  
  return(methods)
}

# Function to optimize heatmap rendering for large datasets
optimizeHeatmapRendering <- function(plot_data, max_points = 10000) {
  if (nrow(plot_data) > max_points) {
    # Stratified sampling to preserve structure
    sample_indices <- sample(nrow(plot_data), max_points)
    return(plot_data[sample_indices, ])
  }
  return(plot_data)
}

# Function to create a grid of heatmaps for multiple markers
createMultiMarkerHeatmapGrid <- function(plot_data, markers, dim1, dim2, 
                                        method = "hex", bins = 30,
                                        color_palette = "plasma", font_size = 10,
                                        ncol = 3) {
  
  # Optimize data for rendering
  opt_data <- optimizeHeatmapRendering(plot_data)
  
  # Create individual plots
  plot_list <- list()
  
  for (i in seq_along(markers)) {
    marker <- markers[i]
    
    p <- createMarkerExpressionHeatmap(
      plot_data = opt_data,
      marker = marker,
      dim1 = dim1, 
      dim2 = dim2,
      method = method,
      bins = bins,
      title = marker,
      font_size = font_size,
      color_palette = color_palette
    )
    
    plot_list[[i]] <- p
  }
  
  # Arrange plots in grid
  if (requireNamespace("gridExtra", quietly = TRUE)) {
    grid_plot <- gridExtra::grid.arrange(grobs = plot_list, ncol = ncol)
    return(grid_plot)
  } else {
    # Fallback: return list of plots
    return(plot_list)
  }
}

# Function to format dimensional method names for display
formatDimMethodName <- function(method_key) {
  switch(method_key,
         "t-SNE" = "t-SNE",
         "UMAP" = "UMAP", 
         "PCA" = "Principal Component Analysis",
         "MDS" = "Multidimensional Scaling",
         method_key)
}

# Function to get suitable axis labels for dimensionality reduction
getDimAxisLabels <- function(method_key) {
  switch(method_key,
         "t-SNE" = c("t-SNE 1", "t-SNE 2"),
         "UMAP" = c("UMAP 1", "UMAP 2"),
         "PCA" = c("PC 1", "PC 2"),
         "MDS" = c("MDS 1", "MDS 2"),
         c("Dimension 1", "Dimension 2"))
}