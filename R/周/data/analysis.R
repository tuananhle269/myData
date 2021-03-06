## =============================================================================
## 更新数据
## =============================================================================
rm(list = ls())
library(tidyverse)
library(data.table)
library(magrittr)
options(width = 120)

## =============================================================================
# setwd("C:/Users/Administrator/Desktop/data")
setwd('/home/william/Documents/周/data')
allDataFile <- list.files() %>% grep('[0-9]{6}\\.xls',., value = T) %>% 
  .[order(.)]
## =============================================================================


## =============================================================================
## !!!!!!!!!!!!!!!!!!!!!!!! 需要先从原来的表格提取 公司名 !!!!!!!!!!!!!!!!!!!!!!!!! ##
dataFile <- "account.csv"

account <- fread(dataFile)
account[, 公司名 := gsub(' ', '', 公司名)]
## =============================================================================


## =============================================================================
year2016 <- grep('2016', allDataFile, value = T)
year2017 <- grep('2017', allDataFile, value = T)
## =============================================================================


## =============================================================================
dt <- lapply(sprintf("%02d", seq(1:12)), function(k) {

  ## ---------------------------------------------------------------------------
  dataFile <- "account.csv"

  account <- fread(dataFile)
  # account
  account[, 公司名 := gsub(' ', '', 公司名)]
  ## ---------------------------------------------------------------------------

  ## ---------------------------------------------------------------------------
  tempDataFile2016 <- grep(paste0('2016',k), year2016, value = T)
  tempDataFile2017 <- grep(paste0('2017',k), year2017, value = T)
  ## ---------------------------------------------------------------------------
  
  ## ---------------------------------------------------------------------------
  dt2016 <- read_excel(tempDataFile2016) %>% as.data.table()
  colnames(dt2016) <- paste0('v',1:4)
  dt2016[, ":="(v2 = as.numeric(v2), 
                v3 = as.numeric(v3),
                v4 = as.numeric(v4))]

  if (! identical(tempDataFile2017, character(0))) {
    dt2017 <- read_excel(tempDataFile2017) %>% as.data.table()
    colnames(dt2017) <- paste0('v',1:4)
    dt2017[, ":="(v2 = as.numeric(v2), 
                  v3 = as.numeric(v3),
                  v4 = as.numeric(v4))]
  } else {
    dt2017 <- data.table(v1 = NA, v2 = NA, v3 = NA, v4 = NA)
  }
  ## ---------------------------------------------------------------------------
  
  
  ## ---------------------------------------------------------------------------
  for (i in 1:nrow(account)) {
    ## -------------------------------------------------------------------------
    ## print(i)
    # i = 74
    if (account[i,公司名] %in% dt2016[,v1]) {
      ## -----------------------------------------------------------------------
      temp2016 <- dt2016[v1 == account[i,as.character(公司名)]] %>% 
        .[, .(v2 = sum(v2), 
              v3 = ifelse(sum(v2) != 0, sum(v4)/sum(v2), 0), 
              v4 = sum(v4))
          ,by = .(v1)]
      
      account[i, ":="(
        a2016 = temp2016[1,v2],
        b2016 = temp2016[1,v3],
        c2016 = temp2016[1,v4]
      )]
      ## ----------------------------------------------------------------------- 
    } else {
      account[i, ":="(
        a2016 = 0,
        b2016 = 0,
        c2016 = 0)]
    }
    
    if (account[i,公司名] %in% dt2017[,v1]) {
      ## -----------------------------------------------------------------------
      temp2017 <- dt2017[v1 == account[i,as.character(公司名)]] %>% 
        .[, .(v2 = sum(v2), 
              v3 = ifelse(sum(v2) != 0, sum(v4)/sum(v2), 0), 
              v4 = sum(v4))
          ,by = .(v1)]
      
      account[i, ":="(
        a2017 = temp2017[1,v2],
        b2017 = temp2017[1,v3],
        c2017 = temp2017[1,v4]
      )]
      ## ----------------------------------------------------------------------- 
    } else {
      account[i, ":="(
        a2017 = 0,
        b2017 = 0,
        c2017 = 0)]
    }
    
    ## -------------------------------------------------------------------------
  }
  ## ---------------------------------------------------------------------------

  ## ---------------------------------------------------------------------------
  setcolorder(account, c('公司名','a2016','a2017','b2016','b2017','c2016','c2017'))
  colnames(account)[2:7] <- c(paste0(colnames(account)[2:7],k))
  return(account)
  ## ---------------------------------------------------------------------------
})

## =============================================================================
res <- Reduce(function(...) merge(..., by = c('公司名')), dt)
## =============================================================================

## =============================================================================
dataFile <- "account.csv"

account <- fread(dataFile)
# account
account[, 公司名 := gsub(' ', '', 公司名)]

account[, id := 1:.N]
## =============================================================================


y <- merge(account[,.(公司名,id)], res, by = '公司名') %>% 
  .[order(id)] %>% 
  .[, id := NULL]
##



## =============================================================================

for (i in 1:nrow(y)) {
  #print(i)
  y[i, ":="(
    a2016 = a201601 + a201602 + a201603 + a201604 + a201605 + a201606 + 
            a201607 + a201608 + a201609 + a201610 + a201611 + a201612,
    a2017 = a201701 + a201702 + a201703 + a201704 + a201705 + a201706 + 
            a201707 + a201708 + a201709 + a201710 + a201711 + a201712,
    
    b2016 = 0,
    b2017 = 0,
    
    c2016 = c201601 + c201602 + c201603 + c201604 + c201605 + c201606 + 
            c201607 + c201608 + c201609 + c201610 + c201611 + c201612,
    c2017 = c201701 + c201702 + c201703 + c201704 + c201705 + c201706 + 
            c201707 + c201708 + c201709 + c201710 + c201711 + c201712
  )]
  y[i,":="(
    b2016 = ifelse(a2016 != 0, c2016 / a2016, 0),
    b2017 = ifelse(a2017 != 0, c2017 / a2017, 0)
  )]
}
openxlsx::write.xlsx(y,'results.xlsx')
## =============================================================================
