# Reference analysis in base R. No forward-fill, winsorisation, or annualisation.
assets <- c('bitcoin', 'gold', 'dxy')

clean_prices <- function(data) {
  required <- c('date', assets)
  names(data) <- tolower(trimws(names(data)))
  if (anyDuplicated(names(data)) || !all(required %in% names(data))) stop('Missing or duplicate columns')
  data <- data[, required]
  data$date <- trimws(as.character(data$date))
  if (any(!grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', data$date))) stop('Use ISO dates')
  dates <- as.Date(data$date, format='%Y-%m-%d')
  if (anyNA(dates) || any(format(dates, '%Y-%m-%d') != data$date)) stop('Invalid dates')
  if (anyDuplicated(data$date)) stop('Duplicate dates')
  incomplete <- Reduce(`|`, lapply(data[assets], function(x) is.na(x) | trimws(as.character(x)) == ''))
  input_rows <- nrow(data)
  dropped <- sum(incomplete)
  data <- data[!incomplete, , drop=FALSE]
  for (asset in assets) {
    data[[asset]] <- suppressWarnings(as.numeric(data[[asset]]))
    if (any(!is.finite(data[[asset]]) | data[[asset]] <= 0)) stop('Prices must be positive finite values')
  }
  data <- data[order(data$date), , drop=FALSE]
  rownames(data) <- NULL
  if (nrow(data) < 2) stop('At least two complete observations required')
  list(rows=data, quality=list(inputRows=input_rows, retainedRows=nrow(data), droppedRows=dropped,
      policy='Complete observed dates only. No forward-fill or interpolation.'))
}

safe_cor <- function(x, y) {
  if (length(x) < 2 || length(x) != length(y) || sd(x) == 0 || sd(y) == 0) return(NA_real_)
  cor(x, y, method='pearson')
}

analyse_prices <- function(prices, window=90L) {
  if (length(window) != 1 || !is.finite(window) || window < 2 || window != as.integer(window)) stop('Invalid rolling window')
  if (nrow(prices) < 2) stop('At least two observations required')
  returns <- data.frame(date=prices$date[-1], lapply(prices[assets], function(p) diff(log(p))))
  stats <- setNames(lapply(assets, function(k) {
    p <- prices[[k]]; r <- returns[[k]]
    list(totalReturn=tail(p, 1)/p[1]-1, meanLogReturn=mean(r), intervalVolatility=if(length(r)>1) sd(r) else NA_real_,
      maxDrawdown=min(p/cummax(p)-1), negativeShare=mean(r<0))
  }), assets)
  if(any(!vapply(stats,function(s) is.finite(s$totalReturn),logical(1)))) stop('Price ratios exceed the supported numeric range')
  matrix <- setNames(lapply(assets, function(a) setNames(lapply(assets, function(b) safe_cor(returns[[a]], returns[[b]])), assets)), assets)
  pairs <- list(bitcoin_gold=c('bitcoin','gold'),bitcoin_dxy=c('bitcoin','dxy'),gold_dxy=c('gold','dxy'))
  rolling <- data.frame(date=character(),bitcoin_gold=double(),bitcoin_dxy=double(),gold_dxy=double())
  if(nrow(returns)>=window) {
    rolling <- data.frame(date=returns$date[window:nrow(returns)])
    for (key in names(pairs)) rolling[[key]] <- vapply(window:nrow(returns), function(i) {
      ix <- (i-window+1):i; pair <- pairs[[key]]; safe_cor(returns[[pair[1]]][ix], returns[[pair[2]]][ix])
    }, numeric(1))
  }
  list(stats=stats, matrix=matrix, returns=returns, rolling=rolling, window=window,
      observations=nrow(prices), maxGap=as.numeric(max(diff(as.Date(prices$date)))))
}

analyse_stress <- function(returns, tail_fraction=.1) {
  if(!is.finite(tail_fraction) || tail_fraction <= 0 || tail_fraction >= 1) stop('Invalid tail fraction')
  cutoff <- as.numeric(quantile(returns$dxy, 1-tail_fraction, type=7))
  selected <- returns[returns$dxy > 0 & returns$dxy >= cutoff, , drop=FALSE]
  summary <- function(data) setNames(lapply(assets, function(k) list(
    meanLogReturn=if(nrow(data)) mean(data[[k]]) else NA_real_,
    negativeShare=if(nrow(data)) mean(data[[k]]<0) else NA_real_, corrDXY=safe_cor(data[[k]],data$dxy))), assets)
  list(threshold=cutoff,n=nrow(selected),selected=selected,baseline=summary(returns),conditional=summary(selected))
}
