
#' Plot Individual Explorer Visits by Param
#'
#' Gather various shiny inputs and return either a ggplot or plotly object. This
#' graph's purpose is to plot AVAL against a visit variable for any PARAMCD,
#' establishing one part of patient narrative found on the Individual Explorer
#' Tab. The graph allows many features to be toggled to enhance the data
#' presented in the plot, including plotting horizontal lines for screening &
#' baseline measurements (when available) and overlaying pertinent OCCDs events
#' (certain milestones, adverse events, and/or con meds) that have occurred
#' during the patients journey.
#'
#' @param watermark If \code{TRUE}, then include a watermark on the output plot
#' @param graph_output A character string specifying either "plotly" or
#'   "ggplot2"
#' @param bds_data A character string containg the name of the BDS Dataset
#' @param usubjid A character string containing Patient number in the form of
#'   USUBJID standards
#' @param input_plot_hor A character string containing variable name to have
#'   horizontal line plotted
#' @param input_visit_var A character string containing the visit variable name
#' @param input_plot_param A character string containing the PARAMCD name /
#'   Value from which to plot AVAL values
#' @param input_plot_adam A character string containing the ADaM dataset name
#' @param input_overlay_events A character vector containing the names of
#'   patient events to plot
#' @param vline_dat The vline data frame that contains x-intercept values for
#'   the corrresponding events selected to be overlain on the plot
#' @param vv_dy_name TA character vector containing the name of the visit
#'   variable(s)
#'
#' @import dplyr
#' @importFrom ggplot2 ggplot aes geom_line scale_x_continuous labs geom_point
#'   annotate geom_vline geom_hline scale_color_manual
#' @importFrom dplyr %>%
#' @importFrom rlang sym
#' @importFrom plotly ggplotly layout config add_annotations
#'
#' @return If graph_output is \code{plotly}, then a plotly object, else if
#'   \code{ggplot} then a ggplot2 object
#'
#' @family indvExp Functions
#' @noRd
#' 
fnIndvExplVisits <- function(
  watermark = FALSE,
  graph_output = "plotly",
  bds_data,
  usubjid,
  input_plot_hor,
  input_visit_var,
  input_plot_param,
  input_plot_adam,
  input_overlay_events,
  vline_dat,
  vv_dy_name
){
  INPUT_visit_var <- sym(input_visit_var)
  
  plot_dat <- 
    bds_data %>%
    filter(!(is.na(!!INPUT_visit_var)) & PARAMCD == input_plot_param) # make sure AVISITN is not missing
  
  # Find the max number of avals for any visit
  most_avals_per_visit <- 
    plot_dat %>%
    group_by(!!INPUT_visit_var) %>%
    summarize(n = n()) %>%
    ungroup() %>%
    summarize(max_avals = max(n, na.rm = TRUE)) %>%
    pull(max_avals)
    
  # initialize man_cols for manual color control
  man_cols <- character(0)
  
  # Create screening or baseline data as necessary
  if("Screening" %in% input_plot_hor){
    plot_scr <- plot_dat %>% subset(regexpr("SCREENING", toupper(VISIT)) > 0) %>% distinct(AVAL) %>% mutate(Visit = "Screening")
  }
  if("Baseline" %in% input_plot_hor){
    plot_base <- plot_dat %>% subset(regexpr("BASELINE", toupper(AVISIT)) > 0) %>% distinct(AVAL) %>% mutate(Visit = "Baseline")
  }
  
  if (nrow(plot_dat) > 0) {
    
    prm   <- unique(plot_dat$PARAM)
    
    if(input_plot_adam %in% c("ADLB","ADLBC") &
       all(c("LBSTNRLO","LBSTNRHI") %in% colnames(plot_dat))){
      lohi <- paste("LO:",unique(plot_dat$LBSTNRLO),"HI:",unique(plot_dat$LBSTNRHI))
    }
    
    # GGPLOT2 OBJECT
    lb_plot <- 
      ggplot2::ggplot(plot_dat, ggplot2::aes(x = !!INPUT_visit_var, y = AVAL)) + 
      ggplot2::geom_line() +
      ggplot2::scale_x_continuous(breaks = seq(min(plot_dat[,input_visit_var]), max(plot_dat[,input_visit_var]), 30)) +
      ggplot2::labs(x = paste0("Study Visit (",input_visit_var,")"),
           y = prm,
           title = paste(prm,"by Relative Study Day"),
           subtitle = paste0(
             ifelse(input_plot_adam %in% c("ADLB","ADLBC") & 
                      all(c("LBSTNRLO","LBSTNRHI") %in% colnames(plot_dat)),
                    paste0("Note: Study's average ",input_plot_param," range shown in blue - ",lohi,"\n")
                    ,""),
             "USUBJID: ",usubjid)
      )	
    
    # IF there are multiple AVALs for a single USUBJID, PARAMCD, and VISIT
    #    AND ADTM or ATPT exists... THEN plot those values on the graph as well
    extra_aval_vars <- c("ATM","ATPT")
    if(most_avals_per_visit > 1 & any(extra_aval_vars %in% colnames(plot_dat))){
      # Grab first available variable that exists and could explain why their are extra avals
      avals_by <- sym(extra_aval_vars[extra_aval_vars %in% colnames(plot_dat)][1])
      # assign("avals_by", sym(extra_aval_vars[extra_aval_vars %in% colnames(plot_dat)][1]),
      #        envir = parent.frame())
      # avals_by <- sym(extra_aval_vars[extra_aval_vars %in% colnames(plot_dat)][1])
      # deliver_avals_by(x = avals_by)
      
      if(avals_by == "ATM") {
        plot_dat <- plot_dat %>% mutate(ATM = as.POSIXct(paste("1970-01-01",ATM)))
      }
      # if discrete atpt, use color aesthetic 
      if(avals_by == "ATPT"){
        lb_plot <- lb_plot + 
          suppressWarnings(
            ggplot2::geom_point(data = plot_dat, na.rm = TRUE, 
              ggplot2::aes(x = !!INPUT_visit_var, y = AVAL, 
                  colour = !!avals_by, # colour aesthetic for for discrete
                  text = paste0(AVISIT,
                                "<br>",input_visit_var, ": ",!!INPUT_visit_var,
                                "<br>",avals_by, ": ",!!avals_by,
                                "<br>",input_plot_param ,": ",AVAL
                  )
              ))
          )
        # manually create colors and updates man_cols
        geom_point_names <- plot_dat %>% distinct(!!avals_by) %>% pull()
        num_names <- length(geom_point_names)
        geom_point_cols <- my_gg_color_hue(2 + num_names)[3:(2+num_names)]
        man_cols <- c(man_cols, setNames(geom_point_cols, geom_point_names))
      } 
      else { # if continuous posixct object (like ATM) then use fill aesthetic for color gradient
        lb_plot <- lb_plot + 
          suppressWarnings(
            ggplot2::geom_point(data = plot_dat, na.rm = TRUE, 
               ggplot2::aes(x = !!INPUT_visit_var, y = AVAL, 
                  fill = !!avals_by, # fill aesthetic for for continuous will make gradient legend
                  text = paste0(AVISIT,
                                "<br>",input_visit_var, ": ",!!INPUT_visit_var,
                                "<br>",avals_by, ": ",!!avals_by,
                                "<br>",input_plot_param ,": ",AVAL
                  )
              ))
          )
      }
      
    } else { # no color by variable in legend or hover text
      avals_by <- ""
      # assign("avals_by", "", envir = parent.frame())
      # with(parent.frame(), { avals_by <- "" })
      # avals_by <- ""
      # deliver_avals_by(x = avals_by)
      
      lb_plot <- lb_plot + 
        suppressWarnings(ggplot2::geom_point(na.rm = TRUE, 
            ggplot2::aes(text = paste0(AVISIT,
                            "<br>",input_visit_var, ": ",!!INPUT_visit_var,
                            "<br>",input_plot_param ,": ",AVAL
              )
          ))
        )
    }
    
    if(watermark & graph_output == "ggplot"){
      
      ## custom draw method to calculate expansion factor on-the-fly
      # drawDetails.watermark <- function(x, rot = 45, ...){
      #   cex <- convertUnit(unit(1,"npc"), "mm", val=TRUE) /
      #     convertUnit(unit(1,"grobwidth", textGrob(x$val)), "mm",val=TRUE)
      #   grid.text(x$lab,  rot=rot, gp=gpar(cex = cex, col="white",
      #                                      fontface = "bold", alpha = 0.5))
      # }
      proof_lab = "tidyCDISC: PROOF ONLY"
      lb_plot <- lb_plot +
        # annotation_custom(xmin=-Inf, ymin=-Inf, xmax=Inf, ymax=Inf,
        #                   grob(lab="tidyCDISC: PROOF ONLY", cl="watermark"))
        
        # Smaller watermark
        ggplot2::annotate("text", x = Inf, y = -Inf, label = proof_lab,
                 hjust=1.1, vjust=-3.3, col="white", fontface = "bold", alpha = 0.8,
                 cex = ifelse(substr(proof_lab,1,4) == 'tidyCDISC',
                              ifelse(avals_by == "" | rlang::is_empty(avals_by),19,14),
                              ifelse(avals_by == "" | rlang::is_empty(avals_by),16,12)
                        )
                 )
      
    }
    
    
    
    # plot vlines using events dataset
    if(length(input_overlay_events) > 0 & input_visit_var %in% vv_dy_name){ #& any(c("ADLB","ADLBC") %in% loaded_adams()) # overlay checkbox won't appear unless this is true
      if (!is.null(vline_dat)){
        if(nrow(vline_dat) > 0){
          
          lb_plot <- lb_plot + 
            suppressWarnings(
              ggplot2::geom_vline(
                data = vline_dat, 
                ggplot2::aes(xintercept = !!INPUT_visit_var,
                             colour = Event,
                             text = paste0(input_visit_var, ": ",floor(!!INPUT_visit_var),"<br>", DECODE)
                ), size = .35
              )
            )
          
          names2 <- c("Milestones","Concomitant Meds","Adverse Events")
          vline_eventtype_cols <- c("#80d1ad", "#f5ae7d", "#a8bde6") # dark version of my_cols
          man_cols <- c(man_cols, setNames(vline_eventtype_cols,names2))
        }
      }
    }
    
    # If lab data, plot the normal low and high values for the drug, add a little space in the bottom margin
    if(input_plot_adam %in% c("ADLB","ADLBC") &
       all(c("LBSTNRLO","LBSTNRHI") %in% colnames(plot_dat))){
      lb_plot <- lb_plot + 
        ggplot2::geom_hline(ggplot2::aes(yintercept = mean(LBSTNRLO)), color = "blue") +
        ggplot2::geom_hline(ggplot2::aes(yintercept = mean(LBSTNRHI)), color = "blue") +
        ggplot2::theme(
          plot.margin = ggplot2::margin(b = 1.2, unit = "cm")
        ) 
    } 
    
    # Plotting hortizontal line
    if("Screening" %in% input_plot_hor){
      if(nrow(plot_scr) > 0){
        lb_plot <- lb_plot +
          ggplot2::geom_hline(plot_scr, mapping = ggplot2::aes(yintercept = AVAL, colour = Visit))
        
        man_cols <- c(man_cols, setNames(my_gg_color_hue(2)[2],"Screening"))
      }
    }
    if("Baseline" %in% input_plot_hor){
      if(nrow(plot_base) > 0){
        lb_plot <- lb_plot +
          ggplot2::geom_hline(plot_base, mapping = ggplot2::aes(yintercept = AVAL, colour = Visit))
        
        man_cols <- c(man_cols, setNames(my_gg_color_hue(2)[1],"Baseline"))
      }
    }
    
    # if a lengend is needed, let's just define the line colors and types in one place
    if(length(input_plot_hor) > 0 | 
       (most_avals_per_visit > 1 & any(extra_aval_vars %in% colnames(plot_dat)))|
       (length(input_overlay_events) > 0 & input_visit_var %in% vv_dy_name)){

      lb_plot <- lb_plot +
        ggplot2::scale_color_manual(values= man_cols)
    }
    # End: ggplot2 object
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    # Create PLOTLY object from ggplot object
    if(graph_output == "plotly"){
      ly <- plotly::ggplotly(lb_plot, tooltip = "text") %>%
        plotly::layout(title = list(text = 
                              paste0(prm," by Study Visit<sup>",
                                     "<br>USUBJID: ",usubjid
                              ))) %>%
        plotly::config(displaylogo = FALSE, 
               modeBarButtonsToRemove= c('sendDataToCloud', 'hoverCompareCartesian','hoverClosestCartesian','autoScale2d'
                                         ,'select2d', 'lasso2d', 'toggleSpikelines'
                                         # , 'toImage', 'resetScale2d', 'zoomIn2d', 'zoomOut2d','zoom2d', 'pan2d'
               ))
      
      # instead, request was made to add caption to bottom of graph
      if(input_plot_adam %in% c("ADLB","ADLBC") &
         all(c("LBSTNRLO","LBSTNRHI") %in% colnames(plot_dat))){
        ly <- ly %>%
          plotly::add_annotations(x = ggplot2::ggplot_build(lb_plot)$layout$panel_params[[1]]$x.range[1],
                          y = -.15, # 15% below graph
                          yref = "paper",
                          text = paste0("<br>Note: Study's average ",input_plot_param," range shown in ",'<em style="color:blue">',"blue",'</em> ',lohi),
                          xanchor = 'left',
                          showarrow = FALSE)
      }
      
      # if watermark is desired, it can be added here
      if(watermark){
        ly <- ly %>%
          plotly::layout(annotations = 
                           list(text="tidyCDISC: PROOF ONLY",
                                xref = "paper",
                                yref = "paper",
                                opacity = 0.1,
                                showarrow = FALSE,
                                font=list(size = 40),
                                textangle=-35)
          )
      }
    }
    
    return(if(graph_output == "ggplot") lb_plot else ly)
  } # if (nrow(plot_dat) > 0)
  
  
  
  
}
