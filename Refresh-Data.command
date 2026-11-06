#!/bin/sh
set -eu
cd "$(dirname "$0")"
if ! command -v Rscript >/dev/null 2>&1; then
  echo 'Rscript is not installed. Install R from https://cran.r-project.org/ and run this file again.'
  exit 1
fi
Rscript --vanilla R/refresh_data.R
printf '\nHistorical snapshot is ready. Opening the explorer…\n'
open dist/index.html
