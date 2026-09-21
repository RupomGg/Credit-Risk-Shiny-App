# Credit Risk Scorer

A small end-to-end project: given a loan applicant's details, predict whether
they're a good or bad credit risk, and explain why. Built in R with a Shiny
front end.

I put this together to get hands-on with R and Shiny specifically for credit
scoring work — the modeling side (classification, benchmarking, evaluating
performance) I already knew from other projects, but R/Shiny as a stack was
new to me. This was the fastest way to actually learn it instead of just
reading about it.

## The data

[Statlog German Credit Data](https://archive.ics.uci.edu/dataset/144/statlog+german+credit+data)
from the UCI Machine Learning Repository — 1,000 real loan applicants, 20
features (checking/savings account status, credit history, loan purpose,
amount, duration, employment length, age, housing, job type, and more), each
labeled good or bad credit risk based on actual repayment outcome.

It's a small, dated dataset (donated in 1994), and it's German consumer
credit, not SME lending. I'm not pretending it's the same as real bank data —
I picked it because it's public, well-documented, and comes with a built-in
cost matrix that mirrors how real credit decisions get made (see below). The
pipeline is the point, not this specific dataset.

## What I did

**1. Cleaned and split the data** — 80/20 train/test, checked the class
balance (about 70% good risk, 30% bad), which is why I evaluated everything
on AUC instead of plain accuracy.

**2. Benchmarked four models** on the same held-out test set:

| Model                              | AUC   |
|-------------------------------------|-------|
| Logistic Regression                 | 0.744 |
| **Random Forest**                   | **0.784** |
| XGBoost (default settings)          | 0.770 |
| XGBoost (tuned, 5-fold CV grid search) | 0.765 |

Random forest won, even after I ran a proper cross-validated grid search to
tune XGBoost. That surprised me a little going in, but it's a fair result —
with only 800 training rows, XGBoost's extra flexibility doesn't have much
room to pay off, and the grid search's "best" score on cross-validation
didn't hold up on the actual test set (classic overfitting to the tuning
process, not the data). Simpler model won on real, unseen data, so that's
what's in the app.

**3. Explainability** — for any single prediction, the app shows a break-down
plot (via the `DALEX` package) of exactly which features pushed that
applicant's score up or down. Not just "63% risk" with no reasoning behind it.

**4. Picked a real decision threshold, not just 50%.** The dataset's own
documentation specifies a cost matrix: calling a bad-risk applicant "good" is
5x more costly than the reverse (a missed default vs. an unnecessarily
declined good applicant). I swept every threshold from 1% to 99% and found
the one that actually minimizes that cost — landed on **24%**, not 50%. Using
that threshold instead of the naive default cuts total expected
misclassification cost by about **34%** on the test set. That's the number I'd
lead with in an interview.

## The app

A Shiny dashboard where you fill in an applicant's details across all 20
features, hit "Assess Risk," and get:

- A predicted default risk percentage
- An approve/decline recommendation based on the 24% cost-optimized threshold
- A live break-down chart showing which specific inputs drove that score

Every dropdown uses plain-language labels ("Overdrawn (< 0 DM)") instead of
the dataset's raw codes ("A11") — someone with no ML background can actually
use it without a lookup table.

## Stack

R, Shiny, `bslib` (dashboard layout/theming), `randomForest`, `xgboost`,
`pROC` (AUC/ROC), `DALEX` (model explainability).

## Running it locally

```r
install.packages(c("shiny", "bslib", "randomForest", "xgboost", "pROC", "DALEX"))
shiny::runApp()
```

## Honest limitations

- Public dataset, not real bank/SME lending data — the pipeline transfers,
  the specific numbers don't.
- Only 1,000 rows total. Good enough to demonstrate the process; a production
  model would need a lot more data and probably more recent economic
  conditions than 1994 Germany.
- The cost ratio (5:1) comes from the dataset's documentation, not from any
  real institution's actual risk appetite — a real deployment would need that
  number set by the business, not assumed.
