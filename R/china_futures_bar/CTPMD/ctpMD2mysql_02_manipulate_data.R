##! ChinaFuturesTickData2mysql_20_manipulate_data.R
#
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
temp <- dt[!(UpperLimitPrice >= 0.0 & LowerLimitPrice >= 0.0)]
info <- data.table(status = paste("              (2) [清除数据]: 价格为负数                              :==> Rows:",
                                  nrow(temp),sep=" ")

                   ) %>% rbind(info,.)

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
#
#
################################################################################
##: STEP 4: Cleaning Data
##: 过滤价格为负数的数据
##: 删除不需要的数据列
##:````````````````````````````````````````````````````````````````````````````
dt <- dt[UpperLimitPrice >= 0.0 & LowerLimitPrice >= 0.0 &
      nchar(InstrumentID) <= 8] %>%
  .[,':='(
    TradingDay = logTradingDay
  )]

#-----------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# 清除数据为 1.797693e+308 的交易所测试数据,
# 我的做法是将其转化为 NA.
cols <- colnames(dt)[6:ncol(dt)]

dt[, (cols) := lapply(.SD, function(x){
  y <- ifelse(x >= 1.797693e+300, NA, x)
  }), .SDcols = cols]

dt <- dt[!is.na(LastPrice)]
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#-------------------------------------------------------------------------------
#
#
#
################################################################################
##: STEP 4: Cleaning Data
##: 清洗重复数据
##:-----------------------------------------------------------------------------

the_duplicated_dt <- duplicated(dt[,.(TradingDay,UpdateTime, UpdateMillisec, InstrumentID
                                      ,LastPrice, Volume, Turnover
                                      ,OpenInterest, UpperLimitPrice, LowerLimitPrice
                                      ,BidPrice1, BidVolume1, BidPrice2, BidVolume2
                                      ,BidPrice3, BidVolume3, BidPrice4, BidVolume4
                                      ,BidPrice5, BidVolume5
                                      ,AskPrice1, AskVolume1,  AskPrice2, AskVolume2
                                      ,AskPrice3, AskVolume3,  AskPrice4, AskVolume4
                                      ,AskPrice5, AskVolume5)
                                   ])

if(sum(the_duplicated_dt)){
  info <- data.table(status = paste("              (3) [清除数据]: 重复的数据行                            :==> Rows:",
                                    sum(the_duplicated_dt),sep=" ")
  ) %>% rbind(info,.)
}else{
  info <- data.table(status = paste("              (3) [清除数据]: 重复的数据行                            :==> Rows:",
                                    0,sep=" ")
  ) %>% rbind(info,.)
}
#
#
#
dt <- dt[!the_duplicated_dt]
#
#
#
################################################################################
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
temp <- dt[!(UpdateTime %in% myDay$trading_period)]
if(nrow(temp) !=0){
  info <- data.table(status = paste("              (4) [清除数据]: 不在正常交易期间内                      :==> Rows:",
                                    nrow(temp),sep=" ")
  ) %>% rbind(info,.)
}else{
  info <- data.table(status = paste("              (4) [清除数据]: 不在正常交易期间内                      :==> Rows:",
                                    0,sep=" ")
  ) %>% rbind(info,.)
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
dt <- dt[UpdateTime %in% myDay$trading_period]
#
#-------------------------------------------------------------------------------
#
print(paste0("#---------- Dealing with Numeric Transformation! -----------------#"))
#-------------------------------------------------------------------------------
# 处理 NumericTime
# 处理 Timestamp 格式
#-------------------------------------------------------------------------------
temp <- dt$TimeStamp
v1 <- substr(temp,10,11) %>% as.numeric() * 3600
v1[v1 > 18*3600] <- (v1[v1 > 18*3600] - 86400)
v2 <- substr(temp,13,14) %>% as.numeric() * 60
v3 <- substr(temp,16,17) %>% as.numeric() * 1
v4 <- substr(temp,19,24) %>% as.numeric() / 1000000
v <- v1 + v2 + v3 + v4
dt[, NumericRecvTime := v]

#-------------------------------------------------------------------------------
temp <- dt$UpdateTime
v1 <- substr(temp,1,2) %>% as.numeric() * 3600
v1[v1 > 18*3600] <- (v1[v1 > 18*3600] - 86400)
v2 <- substr(temp,4,5) %>% as.numeric() * 60
v3 <- substr(temp,7,8) %>% as.numeric() * 1
v4 <- dt$UpdateMillisec  %>% as.numeric() / 1000
v <- v1 + v2 + v3 + v4
dt[, NumericExchTime := v]

#-------------------------------------------------------------------------------
#
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
temp <- dt[abs(NumericRecvTime - NumericExchTime) > 1*60]
if(nrow(temp) != 0){
  info <- data.table(status = paste("              (5) [清除数据]: TimeStamp 与 UpdateTime 相差超过 1 分钟 :==> Rows:",
                                    nrow(temp),sep=" ")
  ) %>% rbind(info,.)
}else{
  info <- data.table(status = paste("              (5) [清除数据]: TimeStamp 与 UpdateTime 相差超过 1 分钟 :==> Rows:",
                                    0,sep=" ")
  ) %>% rbind(info,.)
}
#
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#-------------------------------------------------------------------------------
# 如果 TimeStamp 与 UpdateTime 相差 大于 1分钟，则清洗                ## 1 minute
# before breaktime.
dt <- dt[abs(NumericRecvTime - NumericExchTime) <= 1*60]
#-------------------------------------------------------------------------------
#

breakTime <- myDay[!myDay$trading_period %in% dt[,UpdateTime]]          ## breakTime
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

if(nrow(breakTime) > 1){
  #-----------------------------------------------------------------------------
  temp <- diff(breakTime[,id]) %>% find_bt()
  break_time_detector <- data.table()
  for(i in 1:nrow(temp)){
    break_time_detector <- rbind(break_time_detector,
                                 cbind(breakTime[temp[i,1],trading_period], breakTime[temp[i,2],trading_period])
    )
  }
  colnames(break_time_detector) <- c("BreakBeginTime", "BreakEndTime")

  break_time_detector[,TradingDay := currTradingDay[1,days]]

  break_time_detector[, DataSource := coloID[,paste(colo, csv, sep = ".")]]
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  # if(grepl('history', the_script_main)){##-- 历史的
  #   break_time_detector[, DataFile := c(dataFileNight,dataFileDay)  %>% .[!is.na(.)]  %>% paste(.,collapse = ' & ')
  #                       ]
  # }else{##-- crontab
  #   break_time_detector[, DataFile := ifelse(length(dataFileDay)!=0, dataFileDay, NA)]
  # }
  break_time_detector[, DataFile := logDataFile]
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  setcolorder(break_time_detector, c('TradingDay',"BreakBeginTime", "BreakEndTime",
                                     'DataSource','DataFile'))
  #-----------------------------------------------------------------------------
  info <- info <- data.table(status = paste("              (6) [检测数据]: 连续 60secs 断点的次数                  :==> Rows:",
                                            nrow(break_time_detector),sep=" ")
  ) %>% rbind(info,.)
}else{
  info <- info <- data.table(status = paste("              (6) [检测数据]: 连续 60secs 断点的次数                  :==> Rows:",
                                            0,sep=" ")
  ) %>% rbind(info,.)
}
################################################################################


#-------------------------------------------------------------------------------
#
#-----------------------------------------------------------------------------
# 先做排序处理
#  dt <- dt[,.SD[order(NumericExchTime, Volume, Turnover)],
#       by=.(TradingDay, InstrumentID)]
dt <- dt[,.SD[order(NumericExchTime, Volume, Turnover)],
         by=.(TradingDay, InstrumentID)]

# 处理每个合约的异常排除
not_mono_increasing <- dt[, .SD[!(
  NumericExchTime == cummax(NumericExchTime) &
    Volume          == cummax(Volume) &
    Turnover        == cummax(Turnover)
)], by = .(TradingDay, InstrumentID)]

# mono_increasing
dt <- dt[, .SD[
  NumericExchTime == cummax(NumericExchTime) &
    Volume          == cummax(Volume) &
    Turnover        >= cummax(Turnover) * 0.99 
  ], by = .(TradingDay, InstrumentID)]

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
temp <- not_mono_increasing
if(nrow(temp) !=0){
  info <- data.table(status = paste("              (7) [清除数据]: 成交量、成交额非单调递增                :==> Rows:",
                                    nrow(temp),sep=" ")
  ) %>% rbind(info,.)
}else{
  info <- data.table(status = paste("              (7) [清除数据]: 成交量、成交额非单调递增                :==> Rows:",
                                    0,sep=" ")
  ) %>% rbind(info,.)
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
setcolorder(dt,c("TimeStamp","TradingDay","UpdateTime","UpdateMillisec"
                 ,"InstrumentID", colnames(dt)[6:ncol(dt)]))
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
##############################################################################
dtTick <- dt[,.SD[,
                   .(TimeStamp, UpdateTime, UpdateMillisec
                     ,LastPrice
                     ,Volume, Turnover, OpenInterest
                     ,UpperLimitPrice, LowerLimitPrice
                     ,BidPrice1, BidVolume1, BidPrice2, BidVolume2
                     ,BidPrice3, BidVolume3, BidPrice4, BidVolume4
                     ,BidPrice5, BidVolume5
                     ,AskPrice1, AskVolume1, AskPrice2, AskVolume2
                     ,AskPrice3, AskVolume3, AskPrice4, AskVolume4
                     ,AskPrice5, AskVolume5
                     ,NumericRecvTime,NumericExchTime
                     ,DeltaVolume = c(.SD[1,Volume], diff(as.numeric(Volume)))
                     ,DeltaTurnover = c(.SD[1,Turnover], diff(as.numeric(Turnover)))
                     ,DeltaOpenInterest = c(.SD[1,OpenInterest], diff(as.numeric(OpenInterest)))
                   )
                   ],by=.(TradingDay, InstrumentID)]
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
setcolorder(dtTick,c("TimeStamp","TradingDay","UpdateTime","UpdateMillisec"
                 ,"InstrumentID", colnames(dtTick)[6:ncol(dtTick)]))
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

dt <- dt[,.SD[,
              .(UpdateTime, UpdateMillisec
                ,LastPrice, OpenPrice, HighestPrice, LowestPrice, ClosePrice
                ,Volume, Turnover, OpenInterest
                ,SettlementPrice, UpperLimitPrice, LowerLimitPrice
                ,NumericExchTime
                ,DeltaVolume = c(.SD[1,Volume], diff(as.numeric(Volume)))
                ,DeltaTurnover = c(.SD[1,Turnover], diff(as.numeric(Turnover)))
                ,DeltaOpenInterest = c(.SD[1,OpenInterest], diff(as.numeric(OpenInterest)))
              )
              ],by=.(TradingDay, InstrumentID)] %>%
  .[,":="(Minute = substr(UpdateTime, 1,5))]
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
setcolorder(dt,c("TradingDay","Minute","UpdateTime","UpdateMillisec"
                 ,"InstrumentID", colnames(dt)[5:(ncol(dt)-1)]))
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
##############################################################################
########## Tick data 转化为 Minute data
##############################################################################
#-----------------------------------------------------------------------------
##    if(args_input[3] == "minute"){
print(paste0("#---------- Transforming 1 minute data ! -------------------------#"))
## -----------------------------------------------------------------------------

## =============================================================================
dtMinute <- dt2MinuteBar(dt)
## =============================================================================
## -----------------------------------------------------------------------------
temp <- dtMinute$Minute
v1 <- substr(temp,1,2) %>% as.numeric() * 3600
v1[v1 > 18*3600] <- (v1[v1 > 18*3600] - 86400)
v2 <- substr(temp,4,5) %>% as.numeric() * 60
v <- v1 + v2
dtMinute[, NumericExchTime := v]
## -----------------------------------------------------------------------------


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
setcolorder(dtMinute,c("TradingDay","Minute", "NumericExchTime","InstrumentID"
                    ,colnames(dtMinute)[5:(ncol(dtMinute))]))
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
##############################################################################
info <- data.table(status = paste("              (8) [数据统计]: 1 分钟入库数据共计有:                   :==> Rows:",
                                  nrow(dtMinute),sep=" ")) %>% rbind(info,.)

#-----------------------------------------------------------------------------
print(paste0("#---------- Transforming Daily data ! ----------------------------#"))
#-----------------------------------------------------------------------------
if(format(Sys.time(),"H") > 6){
  suppressMessages({
    suppressWarnings({
      dt_allday <- dt2DailyBar(dt,"allday")
      dt_day    <- dt2DailyBar(dt,"day")
      dt_night  <- dt2DailyBar(dt,"night")
    })
})}

##############################################################################
##########
##############################################################################
info <- data.table(status = c(paste("              (9) [数据统计]: 全天的入库数据共计有:                   :==> Rows:",
                                    nrow(dt_allday),sep=" "),
                              paste("              (10) [数据统计]: 日盘的入库数据共计有:                   :==> Rows:",
                                    nrow(dt_day),sep=" "),
                              paste("              (11)[数据统计]: 夜盘的入库数据共计有:                   :==> Rows:",
                                    nrow(dt_night),sep=" "))
) %>% rbind(info,.)
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
##
