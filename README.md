# hazard_modeling
## Model Variables
    The SAS code creates a hazard model for default. At the start, a set of variables are determined to as good measures
    for determining default. These values include:

    - Quick Ratio
        A firm's reliability on inventory and other current assets to settle short-term debts.
        The quick ratio would be inversely proportional to a firm's survival due to its ability to offload its
        balance sheet.
    - Working Capital Ratio (Current Ratio)
        An indicator as to whether a firm has enough short term assets to cover its short term debt.
        It should be expected that the lower the working capital ratio drops below 1, the more likely
        the firm is to default
    - Return on Total Assets
        A measure of the effectiveness of money invested in a firm. It would be expected that the lower the value,
        the higher chance of default.
    - Ohlson O-Score
        A credit strength test used to determine a firm’s likelihood of failure, with larger scores representing
        a higher probability of bankruptcy. Therefore, as the O-score increases, so should potential defaults.
    - Sales as a percentage of Total Assets
        Determines sales of a firm relative to its total size. The larger the sales as a proportion of firm size
        serves as a marker of better financial health, thus making it less probable for bankruptcy.
    - Face Value of Debt as a percentage of total assets
        An indicator of how high the debt is relative to a firm’s size. Since the firm needs to keep its assets
        above the value of the debt, as debt increases so does the probability of default.
    - Distance to Default
        Distance to default marks the firms distance to face value of debt. As this value decreases,
        the firm approaches default.
    - Probability of Default
        Probability of default is the standard normal distribution of the distance to default used to determine the
        likelihood of default. As this value increases, so should the estimation of default.

    Bankruptcy data added and matched on a per firm, per year basis. From here, a logistical
    regression can be used to determine coefficients for each variable that can be applied to a model used to estimate
    default.

## Model Calculations
    - In-Sample
        For an initial model, an in-sample method is used. The model is created using data from
        1962 to 2014, and then projected over the same time period. This is used as an estimator of whether the variables
        can be used to estimate default.

    - Standard Out-Sample
        A standard out-sample model is then determined. A static model is created from 1962 to 1990, and is
        then used to estimate the bankruptcy for each year from 1991 to 2014.

    - Rolling Out-Sample
        For comparison with the standard out-sample, a rolling out-sample is created. This creates a model from 1962 to
        1990 to estimate the 1991 defaults. For the next year, a new model is created from 1962 to 1991 to determine 1992
        defaults. This is continued to 2014.
            Rolling:
            Tn estimated with 1962 to Tn-1

    - Fixed Window Out-Sample
        For another comparison, a fixed window out-sample model is created. This is created using a rolling 28 year
        window to estimate defaults from 1991 to 2014.
            Fixed Window:
            Tn estimated with 1962+1 to Tn-1

## Model Comparison
    The output data allows for a comparison of the logistic output between the in-sample and standard out-sample.
    For out-samples, there is an averaged table of beta values for each method used.
    Furthermore, the the estimations of bankruptcies were ranked into deciles to observe the effectiveness of the
    variables and methods of modeling. A high number bankruptcies falling within the first and second decile of the
    is an indicator of an effective model.

    For the in-sample and the rolling and fixed window out-sample, the model can be seen as an adequate estimator of
    default, with nearly 85% located in the first and second decile.

    The standard out-sample is the least accurate estimator of default, with the lowest percentage of defaults in the
    first decile. This can be attributed to this method relying on a model that is isn't updating with
    each iteration, thus proving inaccurate the farther the estimated year is from the sample used in the model.

