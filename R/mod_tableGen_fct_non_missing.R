#' Generate frequency of categorical variables using table generator blocks
#'
#' @param column the variable to perform frequency stats on, this also contains
#'   the class of the column based on the data file the column came from
#' @param group the groups to compare for the ANOVA
#' @param data the data to use
#' @param totals the totals data frame that contains denominator N's use when
#'   calculating column percentages
#'
#' @return a frequency table of grouped variables
#'
#' @family tableGen Functions
#' 
#' @keywords tabGen
#' 
#' @noRd
app_non_missing <- function(column, group, data, totals) {
  UseMethod("app_non_missing", column)
}


#' if ADSL supplied look for the column to take frequency of
#' and look for a grouping variable to group_by
#' if data is grouped add total column to the grouped data
#' 
#' @importFrom rlang sym !!
#' @importFrom tidyr pivot_wider
#' @import dplyr
#' 
#' @return frequency table of ADSL column
#' @rdname app_non_missing
#' 
#' @family tableGen Functions
#' 
#' @noRd
app_non_missing.default <- app_non_missing.BDS <- app_non_missing.OCCDS <- app_non_missing.ADAE <- app_non_missing.ADSL <- 
  function(column, group = NULL, data, totals) {
  # # ########## ######### ######## #########
  # column <- "USUBJID"
  # group = "TRT01P"
  # data = ae_data #%>% filter(SAFFL == 'Y')
  # totals <- total_df
  # # ########## ######### ######## #########
  
  # column is the variable selected on the left-hand side
  column <- rlang::sym(as.character(column))
  
  total <- 
    data %>%
    distinct(USUBJID, !!column) %>%
    filter(!is.na(!!column)) %>%
    summarize(n = n_distinct(USUBJID)) %>%
    mutate(n_tot = as.integer(totals[nrow(totals),"n_tot"]),
           prop = n / n_tot,
           x = paste0(n, ' (', sprintf("%.1f", round(prop*100, 1)), ')'),
           temp_col = "Non Missing"
    )  %>%
    rename_with(~paste(column), "temp_col") %>%
    select(!!column, x) 
  
  
  if (is.null(group)) { 
    total
  } else {
    
    if (group == column) {
      stop(glue::glue("Cannot calculate non missing subject counts for {column} when also set as grouping variable."))
    }
    
    group <- rlang::sym(group)
    
    grp_lvls <- get_levels(data[[group]])
    xyz <- data.frame(grp_lvls) %>%
      rename_with(~paste(group), grp_lvls)
    
    grp_tot <- xyz %>%
      left_join(
        totals %>% filter(!!group != "Total")
        # data %>%
        # group_by(!!group) %>%
        # summarize(n_tot = n_distinct(USUBJID)) %>%
        # ungroup()
      )#%>%
      # mutate(n_tot = tidyr::replace_na(n_tot, 0))
      
    groups <- grp_tot %>%
      left_join(
        data %>%
        filter(!is.na(!!column)) %>%
        group_by(!!group) %>%
        summarize(n = n_distinct(USUBJID)) %>%
        ungroup()
      ) %>%
      mutate(n = tidyr::replace_na(n, 0),
             prop = ifelse(n_tot == 0, 0, n / n_tot),
             v = paste0(n, ' (', sprintf("%.1f", round(prop*100, 1)), ')'),
             temp_col = "Non Missing"
      ) %>%
      rename_with(~as.character(column), "temp_col") %>%
      select(-n, -prop, -n_tot) %>%
      tidyr::pivot_wider(id_cols = !!column, names_from = !!group, values_from = v)

    
    cbind(groups, total$x)
  }
}



#' @return NULL
#' @rdname app_non_missing
#' 
#' @family tableGen Functions
#' 
#' @noRd
app_non_missing.BDS <- function(column, group = NULL, data, totals) {
  rlang::abort(glue::glue(
    "Can't calculate Non Missings for BDS yet"
  ))
}

#' @return NULL
#' @rdname app_non_missing
#' 
#' @family tableGen Functions
#' 
#' @noRd
app_non_missing.custom <- function(column, group, data, totals) {
  rlang::abort(glue::glue(
    "Can't calculate mean, data is not classified as ADLB, BDS or OCCDS"
  ))
}
