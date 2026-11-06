#!/usr/bin/env Rscript
# Run from project root. Optional offline path: Rscript R/refresh_data.R --input examples/prices.csv
args <- commandArgs(trailingOnly=TRUE)
if (!file.exists('R/core.R')) stop('Run this command from the Bitcoin-Gold-Explorer project folder.')
source('R/core.R')
if (!requireNamespace('jsonlite', quietly=TRUE)) stop('Install jsonlite first: install.packages("jsonlite")')
value <- function(flag, default=NULL) { i <- match(flag,args); if(is.na(i)) default else {if(i==length(args)) stop(paste('Missing value:',flag));args[i+1]} }
start <- value('--from','2015-01-01')
end <- value('--to','2026-05-24')
input <- value('--input')
out <- value('--output','analysis-output')
if (is.na(as.Date(start)) || is.na(as.Date(end)) || as.Date(start)>as.Date(end)) stop('Invalid requested date range')
dir.create(out,showWarnings=FALSE,recursive=TRUE)
raw <- NULL
if (!is.null(input)) {
  data <- read.csv(input,check.names=FALSE,stringsAsFactors=FALSE,na.strings=c('','NA'))
  kind <- 'imported'; source_label <- paste('User CSV:',basename(input)); title <- 'User-supplied price snapshot'
} else {
  if(!requireNamespace('tidyquant',quietly=TRUE)) stop('Install tidyquant first: install.packages("tidyquant")')
  symbols <- c('BTC-USD','GC=F','DX-Y.NYB')
  message('Downloading Yahoo Finance daily prices. Existing browser data is replaced only after validation succeeds.')
  raw <- as.data.frame(tidyquant::tq_get(symbols,from=start,to=as.character(as.Date(end)+1),get='stock.prices',complete_cases=FALSE))
  if(!all(c('symbol','date','adjusted') %in% names(raw))) stop('Source did not return the required adjusted-price columns')
  raw <- raw[as.Date(raw$date)>=as.Date(start) & as.Date(raw$date)<=as.Date(end),]
  if(!all(symbols %in% unique(raw$symbol))) stop('One or more source symbols failed. No browser snapshot replaced.')
  sets <- lapply(seq_along(symbols),function(i) {
    x <- raw[raw$symbol==symbols[i],c('date','adjusted')]; names(x)[2] <- assets[i]
    if(anyDuplicated(x$date)) stop('Duplicate source dates')
    x
  })
  data <- Reduce(function(x,y) merge(x,y,by='date',all=TRUE),sets)
  kind <- 'historical'; source_label <- 'Yahoo Finance via tidyquant: BTC-USD, GC=F, DX-Y.NYB (adjusted prices)'
  title <- 'Historical snapshot · Yahoo Finance'
}
clean <- clean_prices(data)
analysis <- analyse_prices(clean$rows)
stress <- analyse_stress(analysis$returns)
meta <- list(kind=kind,title=title,source=source_label,generatedAt=format(Sys.time(),'%Y-%m-%dT%H:%M:%SZ',tz='UTC'),
 requestedStart=start,requestedEnd=end,goldProxy=if(kind=='historical') 'GC=F: Yahoo gold futures proxy, not physical gold' else 'User-provided proxy; verify source',
 alignment='Complete common observed dates; no forward-fill or interpolation',symbols=list(bitcoin='BTC-USD',gold='GC=F',dxy='DX-Y.NYB'))
write.csv(clean$rows,file.path(out,'prices.csv'),row.names=FALSE,na='')
if(!is.null(raw)) write.csv(raw,file.path(out,'raw-yahoo.csv'),row.names=FALSE,na='')
meta$inputQuality <- clean$quality
meta$pricesMD5 <- unname(tools::md5sum(file.path(out,'prices.csv')))
summary <- list(meta=meta,quality=clean$quality,analysis=analysis,stress=stress)
jsonlite::write_json(summary,file.path(out,'analysis.json'),auto_unbox=TRUE,pretty=TRUE,na='null',digits=16)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
blob <- jsonlite::toJSON(list(meta=meta,rows=clean$rows),auto_unbox=TRUE,na='null',digits=16,dataframe='rows')
# Escape '<' so a user-supplied label cannot close a script element in a single-file export.
blob <- gsub('<','\\u003c',blob,fixed=TRUE)
js <- paste0('/* Generated price snapshot. See analysis-output for provenance. */\nwindow.EXPLORER_DATA = ',blob,';\n')
target <- 'dist/data.js'; temp <- tempfile(tmpdir='dist',fileext='.js')
writeLines(js,temp,useBytes=TRUE)
if(!file.rename(temp,target)) stop('Could not replace dist/data.js; analysis outputs remain in ',out)
message('Saved ',nrow(clean$rows),' common price observations: ',clean$rows$date[1],' to ',tail(clean$rows$date,1))
message('Browser snapshot updated: dist/data.js. Reload dist/index.html. Source kind: ',kind)
