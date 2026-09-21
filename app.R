library(shiny)
library(bslib)
library(DALEX)
library(randomForest)

rf_model <- readRDS("rf_model.rds")
train_template <- readRDS("train_template.rds")
feature_cols <- setdiff(names(train_template), "risk")

explainer <- explain(rf_model, data = train_template[feature_cols],
                     y = as.numeric(train_template$risk == "bad"), verbose = FALSE)

OPTIMAL_THRESHOLD <- 0.24  # minimizes cost given 5:1 cost ratio (bad-as-good vs good-as-bad)

# ---- Human-readable labels ----
col_labels <- c(
  checking = "Checking Account Status", duration = "Loan Duration (months)",
  credit_history = "Credit History", purpose = "Loan Purpose",
  credit_amount = "Loan Amount (DM)", savings = "Savings Account",
  employment = "Employment Length", installment_rate = "Installment Rate (% of income)",
  personal_status = "Personal Status", other_debtors = "Other Debtors / Guarantors",
  residence_since = "Years at Current Residence", property = "Property Owned",
  age = "Age", other_plans = "Other Installment Plans", housing = "Housing",
  existing_credits = "Existing Credits at This Bank", job = "Job Type",
  liable_people = "Dependents", telephone = "Telephone", foreign_worker = "Foreign Worker"
)

level_labels <- list(
  checking = c(A11 = "Overdrawn (< 0 DM)", A12 = "0-200 DM", A13 = ">= 200 DM", A14 = "No checking account"),
  credit_history = c(A30 = "No credits taken", A31 = "All credits paid duly (this bank)",
                     A32 = "Existing credits paid duly", A33 = "Delay in past payments",
                     A34 = "Critical account / other credits"),
  purpose = c(A40 = "New car", A41 = "Used car", A42 = "Furniture/equipment", A43 = "Radio/TV",
              A44 = "Domestic appliances", A45 = "Repairs", A46 = "Education",
              A48 = "Retraining", A49 = "Business", A410 = "Other"),
  savings = c(A61 = "< 100 DM", A62 = "100-500 DM", A63 = "500-1000 DM",
              A64 = ">= 1000 DM", A65 = "Unknown / none"),
  employment = c(A71 = "Unemployed", A72 = "< 1 year", A73 = "1-4 years",
                 A74 = "4-7 years", A75 = ">= 7 years"),
  personal_status = c(A91 = "Male: divorced/separated", A92 = "Female: divorced/separated/married",
                      A93 = "Male: single", A94 = "Male: married/widowed"),
  other_debtors = c(A101 = "None", A102 = "Co-applicant", A103 = "Guarantor"),
  property = c(A121 = "Real estate", A122 = "Savings agreement / life insurance",
               A123 = "Car or other", A124 = "Unknown / none"),
  other_plans = c(A141 = "Bank", A142 = "Stores", A143 = "None"),
  housing = c(A151 = "Rent", A152 = "Own", A153 = "For free"),
  job = c(A171 = "Unemployed / unskilled", A172 = "Unskilled - resident",
          A173 = "Skilled employee", A174 = "Management / highly qualified"),
  telephone = c(A191 = "None", A192 = "Registered"),
  foreign_worker = c(A201 = "Yes", A202 = "No")
)

label_for <- function(col) if (col %in% names(col_labels)) col_labels[[col]] else col
choices_for <- function(col) {
  lv <- levels(train_template[[col]])
  if (col %in% names(level_labels)) {
    lookup <- level_labels[[col]]
    setNames(lv, ifelse(lv %in% names(lookup), lookup[lv], lv))
  } else {
    setNames(lv, lv)
  }
}

# ---- UI ----
ui <- page_sidebar(
  title = "Credit Risk Scorer",
  theme = bs_theme(bootswatch = "flatly", primary = "#2c3e50"),
  sidebar = sidebar(
    title = "Applicant Details",
    width = 380,
    uiOutput("dynamic_inputs"),
    actionButton("score", "Assess Risk", class = "btn-primary w-100")
  ),
  layout_columns(
    col_widths = c(4, 8),
    uiOutput("risk_box"),
    card(
      card_header("Why this score? (feature contribution)"),
      plotOutput("explain_plot")
    )
  )
)

# ---- Server ----
server <- function(input, output) {
  
  output$dynamic_inputs <- renderUI({
    lapply(feature_cols, function(col) {
      if (is.factor(train_template[[col]])) {
        selectInput(col, label_for(col), choices = choices_for(col))
      } else {
        med <- round(median(train_template[[col]]))
        numericInput(col, label_for(col), value = med)
      }
    })
  })
  
  risk_pct <- reactiveVal(NULL)
  
  observeEvent(input$score, {
    applicant <- train_template[1, ]
    for (col in feature_cols) {
      val <- input[[col]]
      if (is.factor(train_template[[col]])) {
        applicant[[col]] <- factor(val, levels = levels(train_template[[col]]))
      } else {
        applicant[[col]] <- as.numeric(val)
      }
    }
    prob_good <- predict(rf_model, applicant, type = "prob")[, "good"]
    risk_pct(round((1 - prob_good) * 100, 1))
    
    pb <- predict_parts(explainer, new_observation = applicant)
    output$explain_plot <- renderPlot(plot(pb))
  })
  
  output$risk_box <- renderUI({
    r <- risk_pct()
    if (is.null(r)) {
      value_box(title = "Predicted Default Risk", value = "—",
                showcase = icon("shield-halved"), theme = "secondary")
    } else {
      is_risky <- (r / 100) >= OPTIMAL_THRESHOLD
      value_box(
        title = "Predicted Default Risk",
        value = paste0(r, "%"),
        showcase = icon("shield-halved"),
        theme = if (is_risky) "danger" else "success",
        p(if (is_risky) "Recommendation: Decline / Refer" else "Recommendation: Approve"),
        p(class = "text-muted small",
          paste0("Decision threshold: ", OPTIMAL_THRESHOLD * 100, "% (cost-optimized, not the default 50%)"))
      )
    }
  })
}

shinyApp(ui, server)