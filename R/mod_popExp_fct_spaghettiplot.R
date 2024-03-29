#' Spaghetti Plot
#' 
#' Create a spaghetti plot with a time dependent variable as the x-axis
#' and using either the selected response variable
#' or if a PARAMCD is selected, then plot the corresponding value. 
#' Lines are plotted by patient
#' 
#' @param data Merged data to be used in plot
#' @param yvar Selected y-axis 
#' @param time Selected x-axis constrained to time dependent columns
#' @param value If yvar is a PARAMCD then the user must select 
#' AVAL, CHG, or BASE to be plotted on the y-axis
#' 
#' @family popExp Functions
#' @keywords popEx
#' 
#' @return A ggplot object representing the spaghetti plot
#' 
#' @noRd
app_spaghettiplot <- function(data, yvar, time, value = NULL) {
  if (yvar %in% colnames(data)) {
    
    # initialize plot
    p <- ggplot2::ggplot(data) + 
      ggplot2::aes_string(x = time, y = yvar, group = "USUBJID") +
      ggplot2::ylab(best_lab(data, yvar)) +
      ggplot2::xlab(best_lab(data, time))
    
    # initialize title with variables plotted
    var_title <- paste(best_lab(data, yvar), "by", best_lab(data, time))
    
  } else {
    
    # Filter data based on param var selected
    d <- data %>% dplyr::filter(PARAMCD == yvar) 
    
    # initialize title with variables plotted
    var_label <- paste(unique(d$PARAM))
    var_title <- paste(var_label, "by", best_lab(data, time))
    
    # initialize plot
    p <- d %>%
      ggplot2::ggplot() +
      ggplot2::aes_string(x = time, y = value, group = "USUBJID")  +
      ggplot2::ylab(
        glue::glue("{var_label} ({best_lab(d, value)})")
      ) +
      ggplot2::xlab(best_lab(data, time))
  }
  
  # Add common layers to plot
  p <- p + 
    ggplot2::geom_line() +
    ggplot2::geom_point(na.rm = TRUE) +
    ggplot2::theme_bw() +
    ggplot2::theme(text = ggplot2::element_text(size = 12),
                   axis.text = ggplot2::element_text(size = 12),
                   plot.title = ggplot2::element_text(size = 16)) +
    ggplot2::ggtitle(var_title)
  
  return(p)
}
