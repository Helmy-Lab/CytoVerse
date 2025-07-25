# Processed Data Analysis Module for Flow Cytometry Analysis Tool

#' UI for the Processed Data Analysis Module
#' @param id Module ID
#' @return UI elements for processed data analysis
processedDataModuleUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    shinyjs::useShinyjs(),
    
    # Enhanced CSS for better styling - matching compensation and gating modules
    tags$head(
      tags$style(HTML("
        .processed-workflow {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 15px;
          border-radius: 8px;
          margin-bottom: 20px;
        }
        .parameter-group {
          background-color: #e3f2fd;
          padding: 10px;
          border-radius: 5px;
          margin-bottom: 10px;
        }
        .analysis-panel {
          background-color: #f8f9fa;
          padding: 15px;
          border-radius: 8px;
          margin-bottom: 10px;
          border: 1px solid #dee2e6;
        }
        .method-controls {
          background-color: #f1f8e9;
          padding: 8px;
          border-radius: 5px;
          margin: 5px 0;
        }
      "))
    ),
    
    # Workflow Progress Header
    div(class = "processed-workflow",
        h3(icon("table"), "Processed Data Analysis Workflow"),
        p("Upload cleaned data files, configure analysis parameters, and explore statistical results")
    ),
    
    fluidRow(
      # Left Panel - Enhanced Controls with shinydashboard boxes
      column(3,
        # Data Upload Section
        shinydashboard::box(
          title = "Data Upload", status = "primary", solidHeader = TRUE,
          width = 12, collapsible = TRUE,
          
          fileInput(ns("cleanedFile"), "Upload CSV/TSV/Excel File", 
                    accept = c(".csv", ".tsv", ".xlsx"),
                    buttonLabel = "Browse Files...",
                    placeholder = "No file selected"),
          
          helpText(icon("info-circle"), 
                   "Supported formats: CSV, TSV, and Excel files with processed flow cytometry data."),
          
          # Dynamic UI elements
          uiOutput(ns("analysis_type_ui")),
          uiOutput(ns("marker_ui")),
          uiOutput(ns("treatment_ui"))
        ),
        
        # Analysis Configuration Section
        shinydashboard::box(
          title = "Analysis Configuration", status = "success", solidHeader = TRUE,
          width = 12, collapsible = TRUE,
          
          # Dimensionality Reduction Method
          div(class = "parameter-group",
            h5(icon("project-diagram"), "Dimensionality Reduction"),
            selectInput(ns("dimred_method"), "Method:", 
                        choices = c("t-SNE", "UMAP", "PCA", "MDS"), 
                        selected = "t-SNE")
          ),
          
          # Method-specific parameters (replace conditionalPanels with server-side rendering)
          uiOutput(ns("methodParametersUI"))
        ),
        
        # Clustering and Visualization Section
        shinydashboard::box(
          title = "Clustering & Visualization", status = "info", solidHeader = TRUE,
          width = 12, collapsible = TRUE,
          
          # Clustering options
          div(class = "parameter-group",
            h5(icon("sitemap"), "Clustering"),
            numericInput(ns("n_clusters"), "Number of Clusters (k-means):", value = 3, min = 1)
          ),
          
          # Plot dimensions
          div(class = "parameter-group",
            h5(icon("expand-arrows-alt"), "Plot Dimensions"),
            sliderInput(ns("plot_width"), "Plot Width (px):", 
                        min = 300, max = 1200, value = 600, step = 50),
            sliderInput(ns("plot_height"), "Plot Height (px):", 
                        min = 300, max = 1200, value = 600, step = 50)
          )
        ),
        
        # Execute Analysis Section
        shinydashboard::box(
          title = "Execute Analysis", status = "primary", solidHeader = TRUE,
          width = 12,
          
          actionButton(ns("run_cleaned"), "Run Analysis", 
                       class = "btn-primary btn-lg",
                       icon = icon("play"),
                       style = "width: 100%; font-weight: bold;")
        )
      ),
      
      # Main Analysis Panel - Enhanced with shinydashboard boxes
      column(9,
        # Data Overview Section
        shinydashboard::box(
          title = "Data Overview", status = "primary", solidHeader = TRUE,
          width = 12,
          
          tabsetPanel(
            tabPanel("Data Preview", 
                     br(),
                     DT::DTOutput(ns("preview"))),
            tabPanel("Structure Detection", 
                     br(),
                     verbatimTextOutput(ns("structure")))
          )
        ),
        
        # Analysis Results Section
        shinydashboard::box(
          title = "Analysis Results", status = "success", solidHeader = TRUE,
          width = 12,
          
          tabsetPanel(
            tabPanel("Statistical Analysis", 
                     br(),
                     plotlyOutput(ns("plot"))),
            tabPanel("Dimensionality Reduction", 
                     br(),
                     plotlyOutput(ns("dimred_plot"), width = "auto", height = "auto")),
            tabPanel("Summary Statistics", 
                     br(),
                     DT::DTOutput(ns("summary_table")))
          )
        )
      )
    )
  )
}

#' Server function for the Processed Data Analysis Module
#' 
#' @param id Module ID
#' @param app_state Reactive values with global app state
#' @return List with processed data analysis results
processedDataModuleServer <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {

    # Method-specific parameters UI
    output$methodParametersUI <- renderUI({
      req(input$dimred_method)
      
      method <- input$dimred_method
      
      if (method == "t-SNE") {
        div(class = "method-controls", style = "background-color: #e3f2fd; padding: 10px; border-radius: 5px; margin: 10px 0;",
          h6(icon("cog"), "t-SNE Parameters"),
          numericInput(session$ns("perplexity_cleaned"), "Perplexity:", value = 5, min = 2, max = 50),
          helpText("Lower perplexity values work better for smaller datasets.")
        )
      } else if (method == "UMAP") {
        div(class = "method-controls", style = "background-color: #f3e5f5; padding: 10px; border-radius: 5px; margin: 10px 0;",
          h6(icon("cog"), "UMAP Parameters"),
          numericInput(session$ns("neighbors"), "n_neighbors:", value = 5, min = 2, max = 100),
          helpText("Number of neighboring points used in local approximations."),
          numericInput(session$ns("min_dist"), "min_dist:", value = 0.1, min = 0, max = 1, step = 0.05),
          helpText("Minimum distance apart that points are allowed to be in the low dimensional representation.")
        )
      } else if (method == "PCA") {
        div(class = "method-controls", style = "background-color: #e8f5e8; padding: 10px; border-radius: 5px; margin: 10px 0;",
          h6(icon("cog"), "PCA Parameters"),
          numericInput(session$ns("pca_components"), "Number of Components:", value = 2, min = 2, max = 10),
          helpText("Number of principal components to compute and display.")
        )
      } else if (method == "MDS") {
        div(class = "method-controls", style = "background-color: #fff3e0; padding: 10px; border-radius: 5px; margin: 10px 0;",
          h6(icon("cog"), "MDS Parameters"),
          p("MDS uses Euclidean distances by default."),
          tags$small("Note: MDS can be slow for large datasets.")
        )
      }
    })
    

    # Reactive values to store processed data
    cleaned_data <- reactive({
      req(input$cleanedFile)
      ext <- tools::file_ext(input$cleanedFile$name)
      
      # Load data based on file extension
      data <- switch(ext,
                     "csv" = read_csv(input$cleanedFile$datapath),
                     "tsv" = read_tsv(input$cleanedFile$datapath),
                     "xlsx" = read.xlsx(input$cleanedFile$datapath),
                     validate("Unsupported file format"))
      
      return(data)
    })
    
    # Detect CD4/CD8 columns as markers for analysis
    markers_cleaned <- reactive({
      req(cleaned_data())
      # Look for columns starting with 4 or 8 (likely CD4 or CD8 markers)
      grep("^[48]", colnames(cleaned_data()), value = TRUE)
    })
    
    # Display data preview
    output$preview <- DT::renderDT({
      req(cleaned_data())
      DT::datatable(head(cleaned_data(), 10), options = list(scrollX = TRUE))
    })
    
    # Show data structure information
    output$structure <- renderPrint({
      req(cleaned_data())
      list(
        Columns = colnames(cleaned_data()),
        CD4 = grep("^4", colnames(cleaned_data()), value = TRUE),
        CD8 = grep("^8", colnames(cleaned_data()), value = TRUE),
        Numeric_Columns = names(cleaned_data())[sapply(cleaned_data(), is.numeric)],
        Factor_Columns = names(cleaned_data())[sapply(cleaned_data(), is.factor)],
        Character_Columns = names(cleaned_data())[sapply(cleaned_data(), is.character)]
      )
    })
    
    # Dynamic UI for analysis type
    output$analysis_type_ui <- renderUI({
      req(input$cleanedFile)
      selectInput(session$ns("analysis_type"), "Select Analysis Type", 
                  choices = c("Marker Comparison", "Treatment Comparison", 
                              "Fold Change", "Summary Statistics"))
    })
    
    # Dynamic UI for marker selection
    output$marker_ui <- renderUI({
      req(markers_cleaned())
      pickerInput(session$ns("selected_markers"), "Select Markers", 
                  choices = markers_cleaned(), 
                  multiple = TRUE, 
                  selected = markers_cleaned()[1], 
                  options = list(`actions-box` = TRUE))
    })
    
    # Dynamic UI for treatment column selection
    output$treatment_ui <- renderUI({
      req(cleaned_data())
      # Find character or factor columns that might be treatment groups
      potential_treatment_cols <- names(cleaned_data())[sapply(cleaned_data(), function(x) {
        is.character(x) || is.factor(x)
      })]
      
      selectInput(session$ns("selected_treatment"), "Select Treatment Column", 
                  choices = potential_treatment_cols)
    })
    
    # Store analysis results
    analysis_results <- reactiveVal(NULL)
    
    # Run analysis when button is clicked
    observeEvent(input$run_cleaned, {
      req(cleaned_data(), input$selected_markers, input$selected_treatment)
      
      withProgress(message = 'Analyzing data...', value = 0, {
        # Prepare data
        df <- cleaned_data()
        
        # Create long format data for plotting
        incProgress(0.2, detail = "Reshaping data...")
        df_long <- pivot_longer(df, cols = all_of(input$selected_markers),
                                names_to = "Marker", values_to = "Value")
        
        # Run dimensionality reduction
        incProgress(0.4, detail = paste("Running", input$dimred_method, "..."))
        
        # Extract marker data for dimensionality reduction
        df_sel <- df[, input$selected_markers, drop = FALSE] %>%
          mutate(across(everything(), as.numeric)) %>%
          na.omit()
        
        if (nrow(df_sel) < 3) {
          showNotification("Not enough data for dimensionality reduction.", type = "error")
          return(NULL)
        }
        
        # Get treatment and sample info
        treatment <- df[as.numeric(rownames(df_sel)), input$selected_treatment]
        sample_ids <- if ("Sample" %in% colnames(df)) df[as.numeric(rownames(df_sel)), "Sample"] else paste("Sample", seq_len(nrow(df_sel)))
        
        # Run dimensionality reduction
        set.seed(42)  # Ensure reproducibility
        dimred <- NULL
        
        if (input$dimred_method == "t-SNE") {
          # Run t-SNE
          tsne_result <- Rtsne(df_sel, 
                               perplexity = min(input$perplexity_cleaned, floor(nrow(df_sel)/3)), 
                               verbose = FALSE,
                               check_duplicates = FALSE)
          dimred <- tsne_result$Y
        } else if (input$dimred_method == "UMAP") {
          # Run UMAP
          umap_result <- umap(df_sel, 
                              n_neighbors = min(input$neighbors, nrow(df_sel) - 1),
                              min_dist = input$min_dist)
          dimred <- umap_result
        } else if (input$dimred_method == "PCA") {
          # Run PCA
          pca_result <- prcomp(df_sel, scale. = TRUE)
          dimred <- pca_result$x[, 1:input$pca_components]
        } else if (input$dimred_method == "MDS") {
          # Run MDS (classical)
          dist_matrix <- dist(df_sel)  # Euclidean distance by default
          mds_result <- cmdscale(dist_matrix, k = 2)  # 2D projection
          dimred <- mds_result
        }
        
        # Run clustering
        incProgress(0.7, detail = "Clustering data...")
        cluster_labels <- as.factor(kmeans(df_sel, centers = min(input$n_clusters, nrow(df_sel)), nstart = 10)$cluster)
        
        # Create final results data frame
        dimred_df <- data.frame(Dim1 = dimred[,1], Dim2 = dimred[,2], 
                                Treatment = treatment, 
                                Cluster = cluster_labels,
                                Sample = sample_ids)
        
        # Calculate summary statistics
        incProgress(0.9, detail = "Calculating statistics...")
        summary_df <- df_long %>%
          group_by(across(all_of(input$selected_treatment)), Marker) %>%
          summarise(Mean = mean(Value, na.rm = TRUE),
                    SD = sd(Value, na.rm = TRUE), 
                    Median = median(Value, na.rm = TRUE),
                    Min = min(Value, na.rm = TRUE),
                    Max = max(Value, na.rm = TRUE),
                    .groups = "drop")
        
        # Store results
        analysis_results(list(
          long_data = df_long,
          dimred_data = dimred_df,
          summary_data = summary_df,
          treatment_column = input$selected_treatment,
          markers = input$selected_markers,
          dimred_method = input$dimred_method
        ))
        
        # Show success notification
        showNotification("Analysis complete", type = "message")
      })
    })
    
    # Render results plot
    output$plot <- renderPlotly({
      req(analysis_results())
      results <- analysis_results()
      
      # Get app settings
      settings <- app_state$plot_settings
      
      # Create comparison plot based on analysis type
      if (input$analysis_type == "Marker Comparison") {
        # Create box plot of marker values by treatment
        p <- ggplot(results$long_data, aes(x = .data[["Marker"]], y = .data[["Value"]], fill = .data[[results$treatment_column]])) +
          geom_boxplot(alpha = 0.7) +
          theme_minimal(base_size = settings$font_size) +
          theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            plot.title = element_text(hjust = 0.5, face = "bold")
          ) +
          labs(
            title = "Marker Comparison by Treatment",
            x = "Marker",
            y = "Expression"
          )
      } else if (input$analysis_type == "Treatment Comparison") {
        # Create scatter plot of treatment groups
        p <- ggplot(results$long_data, aes(x = .data[[results$treatment_column]], y = .data[["Value"]], color = .data[["Marker"]])) +
          geom_point(position = position_jitter(width = 0.2), alpha = 0.7, size = settings$point_size/2) +
          theme_minimal(base_size = settings$font_size) +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold")
          ) +
          labs(
            title = "Treatment Comparison by Marker",
            x = "Treatment",
            y = "Expression"
          )
      } else if (input$analysis_type == "Fold Change") {
        # Calculate fold change between treatment groups
        fc_data <- results$summary_data %>%
          select(!!sym(results$treatment_column), Marker, Mean) %>%
          pivot_wider(names_from = !!sym(results$treatment_column), values_from = Mean) %>%
          mutate(FoldChange = .[[3]] / .[[2]]) # Assumes there are only 2 treatment groups
        
        # Plot fold change
        p <- ggplot(fc_data, aes(x = Marker, y = FoldChange)) +
          geom_bar(stat = "identity", fill = "steelblue", alpha = 0.7) +
          geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
          theme_minimal(base_size = settings$font_size) +
          theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            plot.title = element_text(hjust = 0.5, face = "bold")
          ) +
          labs(
            title = "Fold Change Analysis",
            x = "Marker",
            y = "Fold Change"
          )
      } else {
        # Summary statistics
        p <- ggplot(results$summary_data, aes(x = Marker, y = Mean, fill = !!sym(results$treatment_column))) +
          geom_bar(stat = "identity", position = position_dodge(), alpha = 0.7) +
          geom_errorbar(
            aes(ymin = Mean - SD, ymax = Mean + SD),
            position = position_dodge(width = 0.9),
            width = 0.25
          ) +
          theme_minimal(base_size = settings$font_size) +
          theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            plot.title = element_text(hjust = 0.5, face = "bold")
          ) +
          labs(
            title = "Summary Statistics by Treatment",
            x = "Marker",
            y = "Mean Expression (with SD)"
          )
      }
      
      # Convert to plotly
      ggplotly(p, width = input$plot_width, height = input$plot_height) %>%
        layout(
          hoverlabel = list(
            bgcolor = "white",
            font = list(family = "Arial", size = settings$font_size)
          )
        )
    })
    
    # Render dimensionality reduction plot
    output$dimred_plot <- renderPlotly({
      req(analysis_results())
      results <- analysis_results()
      
      # Create dimension reduction plot
      p <- ggplot(results$dimred_data, aes(x = Dim1, y = Dim2, color = !!sym(results$treatment_column),
                                           text = paste("Sample:", Sample, "<br>Cluster:", Cluster))) +
        geom_point(alpha = 0.7, size = app_state$plot_settings$point_size/2) +
        theme_minimal(base_size = app_state$plot_settings$font_size) +
        theme(
          plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.title = element_text(face = "bold")
        ) +
        labs(
          title = paste(results$dimred_method, "Projection"),
          x = "Dimension 1",
          y = "Dimension 2"
        )
      
      # Convert to plotly
      ggplotly(p, tooltip = "text", width = input$plot_width, height = input$plot_height) %>%
        layout(
          hoverlabel = list(
            bgcolor = "white",
            font = list(family = "Arial", size = app_state$plot_settings$font_size)
          ),
          xaxis = list(
            scaleanchor = "y", 
            scaleratio = 1
          )
        )
    })
    
    # Render summary table
    output$summary_table <- DT::renderDT({
      req(analysis_results())
      
      # Format summary table with rounded numbers
      DT::datatable(
        analysis_results()$summary_data,
        options = list(
          pageLength = 15,
          scrollX = TRUE
        ),
        caption = "Summary Statistics by Treatment and Marker"
      ) %>%
        formatRound(columns = c("Mean", "SD", "Median", "Min", "Max"), digits = 3)
    })
    
    # Return reactive expressions with results
    return(list(
      cleaned_data = cleaned_data,
      analysis_results = analysis_results
    ))
  })
}