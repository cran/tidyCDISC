
#' Gather Violated Rules
#'
#' Gather applicable Rules into a usable output (gt & df objects) to be included
#' in the pop-up modal when an uploaded data frame violates said rule(s). This
#' function also validates the rules entered to verify they are in the expected
#' format.
#'
#' @param input,output,session Internal parameters for {shiny}.
#' @param disp_type Check for rules that would result in an error (required
#'   variables) or warning (recommended variables)
#' @param datalist A reactive list of data frames (from the data upload module)
#' @param all_df_rules A double-nested list: inner list is named list of
#'   variables names that should result in \code{error} or \code{warn} if
#'   variables do not exist or are missing for ANY data frame. Outer list is
#'   unnamed.
#' @param expl_rules A double-nested list: outer list is a named list
#'   dataframes. Inner list (for each data frame) contains named lists of
#'   variables names that should result in \code{error} or \code{warn} if
#'   variables do not exist or are missing for the specified parent data frame
#' @param df_incl_rules A double-nested list: outer list is a named list
#'   variable names used to identify a particular class of data frame. For
#'   example, the variable name PARAMCD would id BDS class data frames, and the
#'   inner list would contain a named lists of variables names that should
#'   result in \code{error} or \code{warn} if variables do not exist or are
#'   missing for the implied parent data frame.
#' @param df_incl_rules_except_tte A double-nested list: outer list is a named
#'   list variable names used to identify a particular class of data frame. For
#'   example, the variable name PARAMCD would id BDS class data frames WHERE
#'   Time to event (TTE) is an exception, and the inner list would contain a
#'   named lists of variables names that should result in \code{error} or
#'   \code{warn} if variables do not exist or are missing for the implied parent
#'   data frame.
#'
#'
#' @import shiny
#' @import dplyr
#' @importFrom purrr map map2 pmap
#' @importFrom gt gt cols_label text_transform cells_body local_image tab_header
#'   tab_stubhead tab_style  cells_stubhead cols_align cells_row_groups
#'   cols_hide cell_text
#'
#'
#' @return A list of dataframes that are compliant with the rules in addition to
#'   a gt and data frame object which explain which files violate the rules (if
#'   any)
#'
#' @family dataComply Functions
#' @noRd
#' 
gather_reqs <- function(input, output, session, 
                        disp_type = c("error","warn"),
                        datalist = reactive(NULL),
                        all_df_rules = list(error = c(""), warn = c("")),
                        expl_rules = list( list(error = c(""), warn = c("")) ),
                        df_incl_rules = list( list(error = c(""), warn = c("")) ),
                        df_incl_rules_except_tte = list( list(error = c(""), warn = c("")) )
) {
  # for testing:
  # disp_type = "error"
  # study_dir <- 'C:/Users/aclark5/Documents/small_adam/CDISC Pilot Data/'
  # study_dir <- 'C:/Users/aclark5/Documents/small_adam/isis396443_cs3b_csr_data_crt/'
  # filenames <- c('adsl.sas7bdat', 'adtte.sas7bdat', 'advs.sas7bdat')
  # datalist <- purrr::map(file_names, ~ haven::read_sas(file.path(study_directory,.x))) %>%
  #   setNames(toupper(stringr::str_remove(file_names, ".sas7bdat")))
  # adtte <- datalist$ADTTE
  # adtte %>% distinct(PARAMCD)
  
  # Validate disp_type - limiting arg to only "error" or "warn". Stop will alert R developer
  # Technically, this could be removed and the data compliance module would still operate
  if(!(disp_type %in% c("error","warn"))) {
    stop("R Developer must specify either 'error' or 'warn' for disp_type arugment")
  }
  
  # If there are no rules supplied, alert R developer and suggest removing the module from app
  if((is.null(expl_rules) | is.null(names(expl_rules))) & 
     (is.null(df_incl_rules) | is.null(names(df_incl_rules))) &
     (is.null(df_incl_rules_except_tte) | is.null(names(df_incl_rules_except_tte)))  &
     (is.null(all_df_rules) | is.null(names(all_df_rules))) 
  ) {
    stop("No Rules Supplied. Without rules, the data compliance module is useless. Please remove the Module.")
  }
  
  
  
  
  
  # If they exist, Convert double nested rules for all df's into a data frame
  if(!is.null(all_df_rules) & !is.null(names(all_df_rules))) {
    
    # Validate that rules lists were constructed correctly: sublists are error and warn
    ad_sl_nms_correct <- all(unlist(purrr::map(.x = 1:length(all_df_rules), function(x) all(names(all_df_rules[[x]]) %in% c("error","warn")))))
    if(!ad_sl_nms_correct) stop("Sublist Names must be 'error' and 'warn' for each element of 'all_df_rules'")
    
    alldf <- list()
    alldf <- purrr::map(.x = names(datalist()), function(x) alldf[[x]] <- all_df_rules) %>%
      setNames(names(datalist()))%>%
      lapply(data.frame, stringsAsFactors = FALSE) %>%
      bind_rows(.id = "df") %>%
      subset(df %in% names(datalist())) %>% 
      mutate(type_col = if(disp_type == "error") error else warn) %>% 
      subset(type_col != "") %>% 
      distinct(df, type_col)
    
  } else{
    # If the rules don't exist, create an empty data frame
    alldf <- data.frame(df = character(), type_col = character())
  }
  
  
  
  
  
  
  # If they exist, Convert double nested explicit rules lists into a data frame
  if(!is.null(expl_rules) & !is.null(names(expl_rules))) {
    
    # Validate that rules lists were constructed correctly: sublists are error and warn
    expl_sl_nms_correct <- all(unlist(purrr::map(.x = 1:length(expl_rules), function(x) all(names(expl_rules[[x]]) %in% c("error","warn")))))
    if(!expl_sl_nms_correct) stop("Sublist Names must be 'error' and 'warn' for each element of 'expl_rules'")
    
    hdf <- lapply(expl_rules, data.frame, stringsAsFactors = FALSE) %>%
      bind_rows(.id = "df") %>%
      subset(df %in% names(datalist())) %>% 
      mutate(type_col = if(disp_type == "error") error else warn) %>% 
      subset(type_col != "") %>% 
      distinct(df, type_col)
  } else{
    # If the rules don't exist, create an empty data frame
    hdf <- data.frame(df = character(), type_col = character())
  }
  
  
  
  
  
  
  # If they exist, Convert double nested Rules for data frames containing certain vars into a data frame
  if(!is.null(df_incl_rules) & !is.null(names(df_incl_rules))) {
    
    # Validate that rules lists were constructed correctly: sublists are error and warn
    df_incl_sl_nms_correct <- all(unlist(map(.x = 1:length(df_incl_rules), function(x) all(names(df_incl_rules[[x]]) %in% c("error","warn")))))
    if(!df_incl_sl_nms_correct) stop("Sublist Names must be 'error' and 'warn' for each element of 'df_incl_rules'")
    
    # Organize Rules into a dataframe & get concise initial reqs
    dfw_type <-
      lapply(df_incl_rules, data.frame, stringsAsFactors = FALSE) %>%
      bind_rows(.id = "df_var") %>%
      mutate(type_col = if(disp_type == "error") error else warn) %>%
      subset(type_col != "") %>% 
      distinct(df_var, type_col) 

    if(nrow(dfw_type) > 0){
      # Organize data that contains those rules into another df and join them
      # together
      df_vars <- unique(dfw_type$df_var)
      dw <-
        map(.x = names(datalist()), ~df_vars[df_vars %in% colnames(datalist()[[.x]])]) %>%
        setNames(names(datalist())) %>%
        lapply(data.frame, stringsAsFactors = FALSE) %>%
        bind_rows(.id = "df") %>%
        rename("df_var" = "X..i..") %>%
        inner_join(dfw_type, by = c("df_var")) %>%
        distinct(df, df_var, type_col) %>%
        subset(df %in% names(datalist())) %>%
        select(-df_var)
    } else { # nrow(dfw_type) == 0
      # If the rules don't exist, create an empty data frame
      dw <- data.frame(df = character(), type_col = character())
    }
  } else {
    # If the rules don't exist, create an empty data frame
    dw <- data.frame(df = character(), type_col = character())
  }
  
  
  
  # Except for TTE!
  # If rules exist, Convert double nested Rules for data frames containing certain vars into a data frame
  if(!is.null(df_incl_rules_except_tte) & !is.null(names(df_incl_rules_except_tte))) {
    
    # Validate that rules lists were constructed correctly: sublists are error and warn
    df_incl_ette_sl_nms_correct <- all(unlist(map(.x = 1:length(df_incl_rules_except_tte), function(x) all(names(df_incl_rules_except_tte[[x]]) %in% c("error","warn")))))
    if(!df_incl_ette_sl_nms_correct) stop("Sublist Names must be 'error' and 'warn' for each element of 'df_incl_rules_except_tte'")
    
    # Organize Rules into a dataframe & get concise initial reqs
    dfw_ette_type <-
      lapply(df_incl_rules_except_tte, data.frame, stringsAsFactors = FALSE) %>%
      bind_rows(.id = "df_var") %>%
      mutate(type_col = if(disp_type == "error") error else warn) %>%
      subset(type_col != "") %>% 
      distinct(df_var, type_col) 
    
    if(nrow(dfw_ette_type) > 0){
      # Organize data that contains those rules into another df and join them
      # together
      df_ette_var <- unique(dfw_ette_type$df_var)
      dw_ette <-
        map(.x = names(datalist()), ~df_ette_var[df_ette_var %in% colnames(datalist()[[.x]]) & !("CNSR" %in% colnames(datalist()[[.x]]))]) %>%
        setNames(names(datalist())) %>%
        lapply(data.frame, stringsAsFactors = FALSE) %>%
        bind_rows(.id = "df") %>%
        rename("df_var" = "X..i..") %>%
        inner_join(dfw_ette_type, by = c("df_var")) %>%
        distinct(df, df_var, type_col) %>%
        subset(df %in% names(datalist())) %>%
        select(-df_var)
    } else { # nrow(dfw_ette_type) == 0
      # If the rules don't exist, create an empty data frame
      dw_ette <- data.frame(df = character(), type_col = character())
    }
  } else {
    # If the rules don't exist, create an empty data frame
    dw_ette <- data.frame(df = character(), type_col = character())
  }
  
  
  
  
  
  
  # now stack the new rules df's to get a unique set of violated rules... if applicable
  if(
    # suppressing factor to character warning
    suppressWarnings( 
      alldf %>%
      union(hdf) %>%
      union(dw_ette) %>%
      union(dw) 
    ) %>%
    distinct(df, type_col) %>% 
    subset(type_col != "") %>% 
    nrow() == 0
  ) {
    # stop("No Rules Supplied. Without rules, the data compliance module is useless. Please remove the Module.")
    pf <- data.frame(df = character(), type_col = character(),
                     not_exist_disp = character(), missing_disp = character())
    tab <- NULL
    
  } else { # else, there exists violated rules
    
    pf <-
      # suppressing factor to character warning
      suppressWarnings(
        alldf %>%
          union(hdf) %>%
          union(dw_ette) %>%
          union(dw) 
      ) %>%
      distinct(df, type_col) %>%
      arrange(df, type_col) %>%
      mutate(
        type = disp_type,
        not_exist = !unlist(purrr::map2(.x = df, .y = type_col, function(x,y) y %in% colnames(datalist()[[x]]))),
        # unfortunately, the variables that don't exist throw this calculation
        # off.. so we were extremely explicit in map2 below
        missing = ifelse(not_exist == TRUE,
                         ifelse(disp_type == "error", FALSE,TRUE),
                         unlist(purrr::map2(.x = df, .y = type_col, function(x, y)
                           all(as.character(datalist()[[x]][,type_col[df == x & type_col == y & not_exist == FALSE]]) == "") |
                             all(is.na(datalist()[[x]][,type_col[df == x & type_col == y & not_exist == FALSE]]))
                         )) )
        
      ) %>%
      mutate(not_exist_disp = ifelse(not_exist,"X",""),
             missing_disp = ifelse(missing,"X",""),
      )%>%
      subset(not_exist | missing) %>%
      select(df, type_col, not_exist_disp, missing_disp)
    
    
    
    # modify the table displayed using gt, remove a column if just exporting warnings
    tab <- pf %>%
      gt::gt(rowname_col = "type_col" , groupname_col = "df") %>%
      gt::cols_label(not_exist_disp = "Doesn't Exist", missing_disp = "Missing Data") %>%
      gt::text_transform(
        locations = list(gt::cells_body(columns = c(not_exist_disp), rows = not_exist_disp == "X"),
                         gt::cells_body(columns = c(missing_disp), rows = missing_disp == "X")),
        fn = function(X) gt::local_image(filename =
          app_sys('app/www', 'red_x.png'), height = 15)
      ) %>%
      gt::tab_header(
        title = paste(ifelse(disp_type == "error", "Required:", "Optional:"),"reconcile variables below"),
        subtitle = ifelse(disp_type == "error", "and re-upload data",
                          "to experience the app's full functionality")
      ) %>%
      gt::tab_stubhead(label = "Data") %>%
      gt::tab_style(style = gt::cell_text(weight = "bold"), locations = gt::cells_stubhead()) %>%
      gt::cols_align("center") %>%
      gt::tab_style(style = gt::cell_text(weight = "bold"), locations = gt::cells_row_groups())

    
    if(disp_type == "warn") {
      tab <- tab %>% gt::cols_hide(columns = c(not_exist_disp))
    }
  } 
  
  
  return(list(
    # if error, return new list of data frame that comply. If warn, return
    # original list of data frames
    df_list = 
                if(disp_type == "warn") {
                  datalist()
                } else {
                  datalist()[!(names(datalist()) %in% unique(pf$df))]
                },
    gt = tab, # gt object
    df = pf)  # data frame object
  )
}





















