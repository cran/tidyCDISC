#' Generate change from baseline
#' summary statistics using table generator blocks
#'
#' @param column the variable to perform 
#' change from baseline summary stats on,
#' this also contains the class of the column
#' based on the data file the column came from
#' @param week filter the variable's change from baseline by specific week
#' @param group calculate summary statistics per group
#' @param data the data to use 
#' @return an ANOVA table of grouped variables
#' 
#' @family tableGen Functions
#' @keywords tabGen
#' 
#' @noRd
app_chg <- function(column, week, group, data) {
  UseMethod("app_chg", column)
}

#' @return an ANOVA table of grouped variables
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.default <- function(column, week, group, data) {
  rlang::abort(glue::glue(
    "Can't calculate mean because data is not classified as ADLB, BDS or OCCDS"
  ))
}

#' Currently cannot calculate change from baseline from ADSL data
#'
#' @return NULL
#' 
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.ADSL <- function(column, week, group = NULL, data) {
  rlang::abort(glue::glue(
    "Can't calculate change from baseline, {column} from ADSL - please choose a variable from BDS"
  ))
}

#' if BDS filter by paramcd and week
#' We need to calculate the difference in N for this
#' and report missing values from the mean if any
#' 
#' @import dplyr
#' @importFrom rlang sym !! 
#' @return change from baseline summary statistics table
#' 
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.BDS <- function(column, week, group = NULL, data) {
  # column = "DIABP"
  # week = "NONE"
  # group = "SEX"
  # data = tg_data
  
  column <- as.character(column)
  
  if (!column %in% data[["PARAMCD"]]) {
    stop(paste("Can't calculate change from baseline, ", column, " has no CHG values"))
  }
  
  all <- data %>%
    filter(AVISIT == week & PARAMCD == column) %>%
    mean_summary("CHG") %>%
    transpose_df(999)
  
  if (!is.null(group)) {
    
    if (week == "NONE") {
      stop("Please select a week from CHG dropdown to calculate the change from baseline for ", column)
    }
    
    group <- rlang::sym(group)
    grouped <- data %>%
      filter(AVISIT == week & PARAMCD == column) %>%
      group_by(!!group) %>%
      mean_summary("CHG") %>%
      transpose_df(1)
    
    cbind(grouped, all[2])
    
  } else {
    all
  }
}

#' Currently cannot calculate change from baseline from OCCDS data
#' @return NULL
#' 
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.OCCDS <- function(column, week = NULL, group = NULL, data) {
  rlang::abort(glue::glue(
    "Can't calculate change from baseline of OCCDS"
  ))
}

#' Currently cannot calculate change from baseline from OCCDS data
#' @return NULL
#' 
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.ADAE <- function(column, week = NULL, group = NULL, data) {
  rlang::abort(glue::glue(
    "Can't calculate change from baseline of ADAE"
  ))
}

#' Currently cannot calculate change from baseline for custom data
#' @return NULL
#' 
#' @rdname app_chg
#' 
#' @family tableGen Functions
#' 
#' @noRd

app_chg.custom <- function(column, week = NULL, group = NULL, data) {
  rlang::abort(glue::glue(
    "Can't calculate change from baseline, data is not classified as ADLB, BDS or OCCDS"
  ))
}
