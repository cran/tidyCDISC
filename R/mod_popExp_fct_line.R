#' Line Plot
#'
#' Create a line plot with a time variable as the x-axis and using either the
#' selected response variable or if a PARAMCD is selected, then plot the
#' corresponding value to calculate the means. Lines are plotted by patient
#'
#' @param data Merged data to be used in plot
#' @param yvar Selected y-axis
#' @param time Selected x-axis constrained to time dependent columns
#' @param value If yvar is a PARAMCD then the user must select AVAL, CHG, or
#'   BASE to be plotted on the y-axis
#' @param separate character, categorical or factor variable to facet plots by.
#'   Default is 'NONE'.
#' @param color character, categorical or factor variable to COLOR points by.
#'   Default is 'NONE'.
#' @param err_bars logical, defaults to FALSE. Whether or not to include error
#'   bars.
#' @param label_points logical, defaults to FALSE. Whether or not to include
#'   labels on data points.
#' @param gtxt_x_pos if `label_points` == TRUE, then supply a character string
#'   of ("left", "middle", "right") that determines where to place the data
#'   labels relative to the data point
#' @param gtxt_y_pos if `label_points` == TRUE, then supply a character string
#'   of ("bottom", "middle", "top") that determines where to place the data
#'   labels relative to the data point
#' @param add_vert logical, with no default, determines if a vertical reference
#'   line should be added
#' @param vert_x_int if `add_vert` == TRUE, then supply an dbl that exists on
#'   the plot's x-axis to plot the vertical line
#' @param add_hor logical, with no default, determines if a horizontal reference
#'   line should be added
#' @param hor_y_int if `add_hor` == TRUE, then supply an dbl that exists on the
#'   plot's y-axis to plot the vertical reference line
#'
#' @family popExp Functions
#' @keywords popEx
#' 
#' @return A list object containing a ggplot object and a data frame containing the upper and lower bounds
#' 
#' @noRd
app_lineplot <- function(data, yvar, time, value = NULL, separate = "NONE", color = "NONE",
   err_bars = FALSE, label_points = FALSE, gtxt_x_pos = "middle", gtxt_y_pos = "top",
   add_vert, vert_x_int, add_hor, hor_y_int) {
  
  # library(dplyr)
  data0 <- data 
  
  timeN <- paste0(time, "N")
  colorN <- paste0(color, "N")
  separateN <- paste0(separate, "N")
    
  # subset data based on yvar being paramcd or not
  if (yvar %in% colnames(data)) {
    suppressWarnings(
      d0 <- data0 %>% select(USUBJID, time, one_of(timeN), val = yvar, one_of(color, colorN, separate, separateN))
    )
    yvar_label <- yl <- best_lab(data, yvar)
  } else {
    suppressWarnings(
      d0 <- data0 %>%
        dplyr::filter(PARAMCD == yvar) %>%
        select(USUBJID, time, one_of(timeN), PARAM, PARAMCD, val = value, one_of(color, colorN, separate, separateN))
    )
    # do not use best_lab() since this is checking for an empty string
    yvar_label <- ifelse(rlang::is_empty(paste(unique(d0$PARAM))), yvar, paste(unique(d0$PARAM)))
    yl <- glue::glue("{yvar_label} ({best_lab(data, value)})")
  }
  xl <- best_lab(d0, time) 
  y_lab <- paste(ifelse(value == "CHG", "Mean Change from Baseline", "Mean"), yvar_label)
  
  val_sym <- rlang::sym("val")
  
  # Group data as needed to calc means
  suppressWarnings(
    d <-
      d0 %>% varN_fctr_reorder() %>%
      group_by_at(vars(time, one_of(color, separate))) %>%
      summarize(MEAN = round(mean(!!val_sym, na.rm = TRUE), 2),
                # SEM = round(std_err(!!val_sym, na.rm = TRUE),2), # NOT accurate?
                N = n_distinct(USUBJID, na.rm = TRUE),
                n = n(),
                STD = round(sd(!!val_sym, na.rm = TRUE), 2),
                SEM = round(STD/ sqrt(n), 2),
                .groups = "keep") %>%
      ungroup() %>%
      mutate(Lower = MEAN - (1.96 * SEM), Upper = MEAN + (1.96 * SEM)) %>%
      select( -n) %>%
    # wrap text on color or separate variables as needed. Don't change the name
    # of color var, but we do for sep just in case xvar = yvar
    {if(color != "NONE") mutate(., !!sym(paste0("By ", color)) := 
      factor(stringr::str_wrap(!!sym(color), 30), levels = 
        stringr::str_wrap(get_levels(pull(d0, color)), 30))) else .}
  )
  # print(d)
  
  # Returning "my_d" for display
  my_d <- d %>%
    ungroup() %>%
    rename_with(toupper) %>%
    rename_with(~y_lab, "MEAN") %>%
    rename_with(~"Std. Error", "SEM") %>%
    rename_with(~"Std. Deviation", "STD") %>%
    rename_with(~"Visit", time) 
  
  if(err_bars) {
    my_d <- my_d %>%
      rename_with(~"Upper Bound", "UPPER") %>%
      rename_with(~"Lower Bound", "LOWER")
  } else {
    my_d <- my_d %>% select(-UPPER, -LOWER)
  }
  
  # if separate or color used, include those "by" variables in title
  var_title <- paste(y_lab, "by", xl)
  by_title <- case_when(
    separate == color & color != "NONE" ~  paste("\nby", best_lab(data, color)), 
    separate != "NONE" & color != "NONE" ~ paste("\nby", best_lab(data, color), "and", best_lab(data, separate)), 
    separate != "NONE" ~ paste("\nby", best_lab(data, separate)),
    color != "NONE" ~ paste("\nby", best_lab(data, color)), 
    TRUE ~ ""
  )
  
  
  dodge <- ggplot2::position_dodge(.9)
  time_sym <- rlang::sym(time)
  color_sym <- rlang::sym(paste0("By ", color))
  
  # Add common layers to plot
  p <- d %>%
    ggplot2::ggplot() +
    ggplot2::aes(x = !!time_sym, y = MEAN, group = 1,
      text = paste0(
        "<b>", time,": ", !!time_sym, "<br>",# y_lab, 
        ifelse(rep(err_bars, nrow(d)), paste0("MEAN + 1.96*SE: ", sprintf("%.1f",Upper), "<br>"), ""),# y_lab, 
        "MEAN: ", sprintf("%.1f",MEAN),
        ifelse(rep(err_bars, nrow(d)), paste0("<br>MEAN - 1.96*SE: ", sprintf("%.1f",Lower)), ""),
        "<br>SE: ", SEM,
        "<br>SD: ", STD,
        "<br>N: ", N,
        ifelse(rep(color == "NONE", nrow(d)), "", paste0("<br>",color,": ", !!color_sym)),
        # ifelse(rep(color, nrow(d)), paste0("<br>Color: ", sprintf("%.1f",color)), ""),
        "</b>"))  +
    ggplot2::geom_line(position = ggplot2::position_dodge(.91)) +
    ggplot2::geom_point(position = dodge, na.rm = TRUE) +
    ggplot2::labs(x = xl, y = y_lab, title = paste(var_title, by_title)) +
    ggplot2::theme_bw() +
    ggplot2::theme(text = ggplot2::element_text(size = 12),
                   axis.text = ggplot2::element_text(size = 12),
                   plot.title = ggplot2::element_text(size = 16)
                   )
  
  # Add in plot layers conditional upon user selection
  # if (color != "NONE") { p <- p + ggplot2::aes_string(color = color, group = color) }
  if (color != "NONE") { p <- p + ggplot2::aes_string(colour = paste0("`By ", color, "`")) + 
    ggplot2::labs(colour = paste0("By ", color)) +
    ggplot2::theme(plot.title = ggplot2::element_text(size = 16, vjust = 4)
                   ,plot.margin = ggplot2::margin(t = .7, unit = "cm"))
  }
  if (err_bars) {
    p <- p + ggplot2::aes(ymin = Lower, ymax = Upper) +
    ggplot2::geom_errorbar(position = dodge, width = 1.5)
  }
  # if (separate != "NONE") { p <- p + ggplot2::facet_wrap(stats::as.formula(paste(".~", separate))) }
  if (separate != "NONE") {
    lbl <- paste0(separate, ": ", get_levels(pull(d, separate)) ) %>% stringr::str_wrap(50)
    max_lines <- max(stringr::str_count(lbl, "\n")) + 1
    p <- p +
      ggplot2::facet_wrap(stats::as.formula(paste0(".~ ", separate)), 
                          labeller = ggplot2::as_labeller(setNames(lbl , get_levels(pull(d, separate))))
      ) + # strip height is not adjusting automatically with text wrap in the app (though it does locally)
      ggplot2::theme(
        strip.text = ggplot2::element_text(
          margin = ggplot2::margin(t = (5 * max_lines), b = (6 * max_lines))),
        plot.title = ggplot2::element_text(size = 16, vjust = 10)
        ,plot.margin = ggplot2::margin(t = 1.15, unit = "cm")
      ) 
    if(max_lines > 1) p <- p + ggplot2::theme(panel.spacing.y = 
                                 ggplot2::unit((.5 * max_lines),"lines"))
  }
  # if (by_title != "") {p <- p + ggplot2::theme(plot.margin = ggplot2::margin(t = 1.25, unit = "cm"))}
  
  if(label_points){
    x_scale <- ggplot2::layer_scales(p)$x$range$range
    if(all(!is.numeric(x_scale))){
      x_nums <- sort(as.numeric(as.factor(x_scale)))
      range <- diff(c(min(x_nums), max(x_nums)))
    } else {
      range <- diff(x_scale)
    }
    x_nudge_val <- range * .04 #* (plot_col_num /2)
    y_nudge_val <- diff(ggplot2::layer_scales(p)$y$range$range)*.04
    # gtxt_x_pos <- "right" #c("left", "middle", "right")
    # gtxt_y_pos <- "top"   #c("bottom", "middle", "top")
    gglook <- ggplot2::layer_data(p) %>% # to grab accurate x coordinates from existing ggplot obj since they've been transformed through position_dodge()
      mutate(lab = sprintf("%.1f",y))
    
    ps <- length(unique(gglook$PANEL))
    
    colour_vector <- gglook %>%
      select(colour, PANEL) %>%
      slice(rep(1:n(), ps)) %>%
      mutate(id = rep(1:ps, each = nrow(gglook))
             , colour2 = ifelse(id == PANEL, colour, NA_character_)
      ) %>% pull(colour2) %>% as.character()
    
    p <- p + ggplot2::geom_text(data = gglook, inherit.aes = FALSE, show.legend = FALSE,
                                ggplot2::aes(x = x, y = y, label = lab, group = colour, text = "")
                     , color = colour_vector
                     # , hjust = .5, vjust = -1 # position = dodge, # these all don't work with plotly
                     , nudge_y = translate_pos(gtxt_y_pos) * y_nudge_val
                     , nudge_x = translate_pos(gtxt_x_pos) * x_nudge_val,
      )
  }
  if(add_vert){
    if(is.character(vert_x_int)){
      time_lvls <- get_levels(d[[time]])
      p <- p + ggplot2::geom_vline(xintercept = which(time_lvls == vert_x_int), color = "darkred")
    } else { # numeric
      p <- p + ggplot2::geom_vline(xintercept = as.numeric(vert_x_int), color = "darkred")
    }
  }
  if(add_hor){
    p <- p + ggplot2::geom_hline(yintercept = hor_y_int, color = "darkred")
  }
  
  
  return(list(plot = p, data = my_d))
}
