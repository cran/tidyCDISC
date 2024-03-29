#' GT Column Names
#' 
#' @param col_names A vector of column names
#' @param col_total A vector of column totals
#' 
#' @description The function creates the labels for each column using the total function so the columns are now NAME N= X
#' @export
#' @keywords tabGen_repro
#' 
#' @return A character object of class \code{from_markdown}.
#' 
#' @importFrom purrr map2
#' @importFrom gt md
#' @importFrom glue glue
#' @importFrom rlang set_names
#' 
#' @examples 
#' data(example_dat2, package = "tidyCDISC")
#' 
#' labels <- col_for_list_expr(example_dat2$col_names, example_dat2$col_totals)
#' labels
#' 
#' if (interactive()) {
#' # TG table without nice column labels or totals
#' example_dat2$TG_table
#' 
#' # TG table with nice column labels and totals
#' gt::cols_label(example_dat2$TG_table, .list = labels)
#' }
col_for_list_expr <- function(col_names, col_total) {
  purrr::map2(col_names, col_total, ~ gt::md(glue::glue("**{.x}** <br> N={.y}"))) %>%
    rlang::set_names(col_names)
}


#' My GG Color Hue
#'
#' Grab specific colors from the ggplot2 default color palette of length n
#'
#' @param n An output reactive dataframe from IDEAFilter
#'
#' @return character vector of hex colors of length n
#'
#' @family indvExp Functions
#' @noRd
#'   
my_gg_color_hue <- function(n) {
  hues = seq(15, 375, length = n +1)
  hcl(h = hues, l = 65, c = 100)[1:n]
}

#' Standard Error Calculation
#' 
#' Calculates the square root of variance divided by n
#'
#' @param x A numeric vector
#' @param na.rm logical, should NA's be removed? Defaults to FALSE
#'
#' @return numeric, representing the standard error
#'
#' @family tableGen Functions
#' @noRd
#'  
std_err <- function(x, na.rm=FALSE) {
  if (na.rm) x <- na.omit(x)
  sqrt(var(x)/length(x))
}

#' Translate the position of into a integer needed for ggplot2
#' @param dir the strings to capitalize
#' @noRd
#' 
translate_pos <- function(dir){
  if(dir %in% c("left","bottom")) -1
  else if(dir %in% c("right","top")) 1
  else 0 # middle
}

#' Capitalize the first letter of a string
#' @param y the strings to capitalize
#' @noRd
#' 
CapStr <- function(y) {
  c <- strsplit(y, " ")[[1]]
  paste(toupper(substring(c, 1,1)), substring(c, 2),
        sep="", collapse=" ")
}


#' transpose dataframes so they can all 
#' be used with rbind to generate
#' the gt tables
#' 
#' @param df the dataframe to transpose
#' @param num the number of rows to return
#' @importFrom dplyr mutate rename
#' @importFrom tidyr pivot_longer pivot_wider
#' @noRd
#' 
transpose_df <- function(df, num) {
  t_df <- df %>%
    dplyr::mutate("rowname" = rownames(.), .before = 1) %>%
    tidyr::pivot_longer(-"rowname") %>%
    tidyr::pivot_wider(names_from = "rowname") %>%
    dplyr::rename("rowname" = "name")
  return(t_df[-num,])
}

#' Identify Names of Columns
#' 
#' @description A function to transform the \code{gt} row names from generics to the column name and the total N of
#' each column
#'
#' @param data the data to create columns with
#' @param group whether to group the data to calculate Ns
#'  
#' @export
#' @keywords tabGen_repro
#' 
#' @return A character vector
#' 
#' @examples 
#' data(adsl, package = "tidyCDISC")
#' 
#' # Values of TRT01P
#' unique(adsl$TRT01P)
#' 
#' # Common row names based on TRT01P
#' common_rownames(adsl, "TRT01P")
common_rownames <- function(data, group) { 
  if (is.null(group) ) { #| group == "NONE"
    vars <- c("Variable", "Total")
  } else {
    if(is.factor(data[[group]])){
      # droplevels() get's rid of levels that no longer exist in the data post filtering
      lvls <- levels(data[[group]]) # removed droplevels() to retain all trt grps
    } else {
      lvls <- sort(unique(data[[group]]))
    }
    vars <- c("Variable", lvls, "Total")
    vars[vars == ""] <- "Missing"
  }
  return(vars)
}

# #' Figure out which reactive data.frame to use
# #'
# #' @param d a string, naming a data.frame
# #' @param ae an AE reactive data frame
# #' @param alt an alternative reactive data frame
# #' @noRd
# #'
# data_to_use_str <- function(d, ae, alt) {
#   if (dat == "ADAE") { ae }
#   else alt
# }

# #' Figure out which reactive data.frame to use
# #'
# #' @param x a string, naming a data.frame. Either
# #' @noRd
# "data_to_use_str"
# # function included in mod_tableGen... not here.
# # data_to_use_str <- function(x) {
# #   if (x == "ADAE") ae_data() else all_data()
# # }



#' Convert actions performed on from an IDEAFilter output dataframe into text
#'
#' Function accepts a filtered data object from IDEAFilter (shiny_data_filter
#' module) and translates the information to be more readable to the lay person
#' (a non- R programmer) but still assumes some knowledge of filtering
#' expressions. IE, the app is for an audience who is familar with programming
#' (SAS programmers).
#'
#' @param filtered_data An output reactive dataframe from IDEAFilter
#' @param filter_header A header to label the output string

#'   DO NOT REMOVE.
#' @import dplyr
#' @importFrom dplyr %>%
#' @importFrom purrr map2
#' @importFrom stringr str_locate_all str_remove str_replace_all
#' @importFrom utils capture.output
#' @importFrom tidyr as_tibble
#' @importFrom shiny HTML
#' 
#' @return An HTML string
#' @noRd
#' 
filters_in_english <- function(filtered_data, filter_header = "Filters Applied:"){
  
  # grab the output
  orig_code <- paste(utils::capture.output(attr(filtered_data, "code")),collapse = "")
  # orig_code <- 'processed_data %>% filter(ABIFN1 %in% c(NA, "NEGATIVE")) %>% filter(ABIFN1 %in% c(NA, "POSITIVE"))'
  # convert double quotes to single quotes
  code_text <- orig_code %>%
    stringr::str_remove("^.*?\\%>\\%") %>%
    stringr::str_replace_all('\"', "\'")
  
  # find the character position for the end of the string
  len <- nchar(code_text)
  
  # find the start of the variable expressions using position of "filter"
  f_loc <- str_locate_all(code_text,"filter\\(")
  filter_loc <- tidyr::as_tibble(f_loc[[1]])
  var_st <- filter_loc$end + 1
  
  # find the end of variable expression susing position of "%>%"
  p_loc <- str_locate_all(code_text,"\\%\\>\\%") # have to use this
  pipe_loc <- tidyr::as_tibble(p_loc[[1]])
  num_pipes <- nrow(pipe_loc)
  var_end <- c(pipe_loc$start[ifelse(num_pipes == 1, 1, 2):num_pipes] - 3, len - 1) # ifelse(num_pipes == 1, 1, 2)
  
  # use map2, to apply multiple arguments to the substr function, returing a list
  filter_vectors <- map2(.x = var_st, .y = var_end, function(x,y) substr(code_text,x,y))
  my_msgs <- filter_vectors[!(is.na(filter_vectors) | filter_vectors == "")] # get rid of NA msgs
  
  # clean up messages to read more naturally
  disp_msg <- gsub("\\%in\\%","IN",
                   gsub("c\\(","\\(",
                        gsub("\\(NA","\\(Missing",
                             gsub(".na",".Missing",
                                  gsub("   "," ", # 3 spaces
                                       gsub("  "," ", # 2 spaces
                                            gsub("\\|","OR",
                                                 gsub("\\&","AND",
                                                      my_msgs
                                                 ))))))))
  
  # format as html in a specific format, with indentation
  return(HTML(paste0("<b>",filter_header,"</b><br/>&nbsp;&nbsp;&nbsp;&nbsp;"
                     ,paste(disp_msg, collapse = "<br/>&nbsp;&nbsp;&nbsp;&nbsp;"))))
}

#' Get Factor Levels
#'
#' Extracts the factor levels of a vector or returns the unique values if the vector is not a factor.
#'
#' @param x a vector
#'   
#' @return x vector 
#' 
#' @export
#' @keywords helpers
#' 
#' @references A character vector containing the levels of the factor/vector
#' 
#' @examples 
#' data(adae, package = "tidyCDISC")
#' 
#' # Create levels based on VARN
#' varN_fctr_adae <- varN_fctr_reorder(adae)
#' 
#' # `adae` does not have factor but `varN_fctr_adae` does
#' levels(adae$RACE)
#' levels(varN_fctr_adae$RACE)
#' 
#' # `get_levels()` either creates the factor or retrieves it
#' get_levels(adae$RACE)
#' get_levels(varN_fctr_adae$RACE)
get_levels <- function(x) {if(is.factor(x)) levels(x) else sort(unique(x), na.last = TRUE) } 



#' %quote%
#' @param x test if null
#' @param y return if x is null
#' @return either y or a string
#' @noRd
#'
`%quote%` <- function(x,y) {
  if (is.null(x)) {
    y
  } else {
    paste0("\'",x,"\'") #sQuote(x) # old
  }
}



#' Re-order Factor Levels by VARN
#' 
#' Function to that looks for VARN counterparts to any character or factor VAR
#' variables in any dataframe and re-orders there factor levels, taking the lead
#' from VARN's numeric guide.
#' 
#' @param data a dataframe, including one enriched with SAS labels attributes
#' 
#' @importFrom sjlabelled get_label set_label
#' @importFrom purrr walk2 
#' 
#' @export
#' @keywords helpers
#' 
#' @return The data frame after having factor levels re-ordered by VARN
#' 
#' @examples 
#' data(adae, package = "tidyCDISC")
#' 
#' varN_fctr_adae <- varN_fctr_reorder(adae)
#' 
#' unique(adae[,c("AGEGR1", "AGEGR1N")])
#' levels(adae$AGEGR1)
#' levels(varN_fctr_adae$AGEGR1)
#' 
#' unique(adae[,c("RACE", "RACEN")])
#' levels(adae$RACE)
#' levels(varN_fctr_adae$RACE)
varN_fctr_reorder <- function(data) {
  # rm(data)
  # data <- all_data
  # Now to refactor levels in VARN order, if they exist:
  # save the variable labels into savelbls vector
  savelbls <- sjlabelled::get_label(data)
  
  # identify all char - numeric variables pairs that need factor re-ordering
  cols <- colnames(data)
  non_num_cols <- c(subset_colclasses(data, is.factor),
                    subset_colclasses(data, is.character))
  varn <- paste0(non_num_cols,"N")[paste0(non_num_cols,"N") %in% cols]
  varc <- substr(varn,1,nchar(varn) - 1)
  
  if(!rlang::is_empty(varn)){
    for(i in 1:length(varn)){
      this_varn <- as.character(varn[i])
      this_varc <- varc[i]
      this_varn_sym <- rlang::sym(this_varn)
      this_varc_sym <-rlang::sym(this_varc)
      pref_ord <- data %>% select(one_of(this_varc, this_varn)) %>% distinct() %>% arrange(!!this_varn_sym)
      data <-
        data %>% mutate(!!this_varc_sym := factor(!!this_varc_sym,
                          levels = unique(pref_ord[[this_varc]])))
      # return(data)
    }
  }

  # copy SAS labels back into data
  data <- sjlabelled::set_label(data, label = savelbls)
  return(data)
}

error_handler <- function(e) {
  UseMethod("error_handler")
}

error_handler.default <- function(e) {
  conditionMessage(e)
}

error_handler.purrr_error_indexed <-
  `error_handler.dplyr:::mutate_error` <- function(e) {
  e$parent$message
}

error_handler.rlang_error <- function(e) {
  stringr::str_replace_all(rlang::cnd_message(e), "\n.*? ", " ")
}

#' Extract best variable label
#'
#' A function that will grab a label attribute from a given variable, or if one
#' doesn't exist, it will just use the variable name
#'
#' @param data a data.frame, hopefully containing variable label attributes
#' @param var_str you guessed it, the name of a variable inside of `data`, in
#'   the form of a string
#'   
#' @return a string containing a useful label
#'
#' @noRd
best_lab <- function(data, var_str) {
  attr(data[[var_str]], "label") %||% var_str
}






