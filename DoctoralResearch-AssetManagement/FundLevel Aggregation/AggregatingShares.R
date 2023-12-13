library(haven)
library(readr)
library("lubridate")
library("labelled")
library("dplyr")
library("sjlabelled")
library("zoo")
library(stringr)
library(parallel)
library(DescTools)

setwd("D:/DATOS/CRSP Mutual funds")
# Calculating Flows at fund level: Portfolio Number
suma=function(x){
  if(sum(is.na(x))==length(x)){
    r=NA
  }else{
    r=sum(x, na.rm=T)
  }
  return(r)
}


Mean=function(x){
  if(sum(is.na(x))==length(x)){
    r=NA
  }else{
    r=mean(x, na.rm=T)
  }
  return(r)
}

# Importing the Data
MonthlyReturns <- read_dta("MonthlyReturns.dta")
# Homogenize the day within Monthly Returns
lubridate::day(MonthlyReturns$caldt) <- 28
# Dealing with noisy returns above 100 % 


# Dealing with Portfolio Returns (Dealing with Outliers)
# We need to give a treatment to returns above 1 or -1 to not inntroduce noise in alphas and netflows
MonthlyReturns[which((MonthlyReturns$mret>1)|!(MonthlyReturns$mret>-1)), "mret"]=NA

MonthlyFundnoPortnoMAP <- read_dta("MonthlyFundnoPortnoMAP.dta")
MonthlyFundnoPortnoMAP[, "crsp_fundno"]=as.numeric(MonthlyFundnoPortnoMAP$crsp_fundno)
Data=inner_join(MonthlyFundnoPortnoMAP,MonthlyReturns)
Data=Data%>%arrange(crsp_portno,caldt)


# Generate Weights, later aggregate by value-weighting
Data=Data%>%group_by(crsp_portno, caldt)%>%
  mutate(TNA=suma(mtna))%>%
  mutate(Weights=mtna/TNA)%>%
  mutate(Weights=ifelse(is.na(mret),NA,Weights))%>%
  mutate(NWeights=Weights/suma(Weights))%>%
  mutate(Ret=suma(NWeights*mret))%>%ungroup()%>%
  select(caldt, crsp_portno, FundId,  TNA, Ret)%>%
  distinct()%>%
  mutate(mtna=TNA, mret=Ret)%>%
  select(caldt, crsp_portno, FundId, mtna, mret)%>%
  distinct()



#################################################################
#################################################################
## SUMMARY INFORMATION
#################################################################
#################################################################

fundsummary <- read_dta("Monthlysummary.dta") # Monthly Fund Summary
# Fixing the Date
# Homogenize the day within Monthly Summary
lubridate::day(fundsummary$caldt)<-28


#Fixing negative reports

fundsummary[which(fundsummary$per_cash<0),"per_cash"]=NA
fundsummary[which(fundsummary$mgmt_fee<0),"mgmt_fee"]=NA
fundsummary[which(fundsummary$exp_ratio<0),"exp_ratio"]=NA

# Cash Holdings: per_cash
fundsummary=fundsummary%>%group_by(crsp_portno, caldt)%>%
  mutate(TNA=suma(mtna))%>%
  mutate(Weights=mtna/TNA)%>%
  mutate(Weights=ifelse(is.na(per_cash),NA,Weights))%>%
  mutate(NWeights=Weights/suma(Weights))%>%
  mutate(Cash=suma(NWeights*per_cash))
  mutate(per_cash=Cash)%>%
  distinct()

  # Management Fee: mgmt_fee
  
  fundsummary=fundsummary%>%group_by(crsp_portno, caldt)%>%
    mutate(TNA=suma(mtna))%>%
    mutate(Weights=mtna/TNA)%>%
    mutate(Weights=ifelse(is.na(mgmt_fee),NA,Weights))%>%
    mutate(NWeights=Weights/suma(Weights))%>%
    mutate(MGMTF=suma(NWeights*mgmt_fee))
  mutate(mgmt_fee=MGMTF)%>%
    distinct()
  
  # Expense Ratio
  
  fundsummary=fundsummary%>%group_by(crsp_portno, caldt)%>%
    mutate(TNA=suma(mtna))%>%
    mutate(Weights=mtna/TNA)%>%
    mutate(Weights=ifelse(is.na(exp_ratio),NA,Weights))%>%
    mutate(NWeights=Weights/suma(Weights))%>%
    mutate(EXPR=suma(NWeights*exp_ratio))
  mutate(exp_ratio=EXPR)%>%
    distinct()
  
  
  # Reduce dimmensionality at portfolio level
  fundsummary=fundsummary%>%ungroup()%>%
    select(caldt, crsp_portno,  per_cash, mgmt_fee, exp_ratio)%>%
    distinct()%>%

  # Connecting Returns with summary data
    
  Data=inner_join(Data, fundsummary)

  
    
    
  # Adding Labels and Export Data
  L=c("caldt", "Fund Id: CRSP", "Fund Id: MsD", "Monthly TNA: Sum", "Monthly Return: VWA by TNA",
      "Cash Holdings", "Management Fee", "Expense Ratio")
  
  DataRet=set_variable_labels(Data, .labels =L)
  
  
  write_dta(DataRet,"MonthlyPortfolioData.dta")
  
