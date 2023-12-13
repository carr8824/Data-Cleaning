library(haven)
library(readr)
library(lubridate)
library(labelled)
library(dplyr)
library(sjlabelled)
library(zoo)
library(stringr)
library(parallel)
library(DescTools)
library(sjlabelled)

modef=function(x){
  m=Mode(x,na.rm = T)[1]
  if(is.na(m)){
    r=sort(x[which(!is.na(x))])[1]
  }else{
    r=m
  }
  return(r)
}

setwd("D:/DATOS/CRSP Mutual funds")
#FundnoPortnoMAP <- read_dta("FundnoPortnoMAP.dta")
FundnoPortnoMAP <- read_dta("ALLMAP.dta")

l=get_label(FundnoPortnoMAP)

# Homogenize the day within fundnoPortno MAP

lubridate::day(FundnoPortnoMAP$begdt)=28
lubridate::day(FundnoPortnoMAP$enddt)=28

class(FundnoPortnoMAP$enddt)
# There is a problem the file only maps until july of 2021, lets extrapolate until december of 2022
FundnoPortnoMAP=FundnoPortnoMAP%>%
  mutate(enddt= as.Date(ifelse(enddt > as.Date("2021-03-28"),
                               as.Date("2022-12-28"),
                               enddt)))

# FUNDNOPORTNOMAP

Fundno=unique(FundnoPortnoMAP$crsp_fundno)



monthlyMAP=function(FundnoPortnoMAP,Fundno){
  sample=filter(FundnoPortnoMAP,crsp_fundno==Fundno)
  sample=distinct(sample)
  nn=names(sample)
  nn=nn[which(!(nn %in% c("begdt","enddt")))]
  MAPRES=matrix(NA,nrow=0,ncol=(length(nn)+1))
  
  for(i in 1:nrow(sample)){
    n1=as.matrix(sample[i,"begdt"])
    n2=as.matrix(sample[i,"enddt"])
    
    EDATE=as.data.frame(seq.Date(as.Date(n1),as.Date(n2),by="month"))
    
    map=as.matrix(sample[i,nn])
    
    MAPDATA=cbind(EDATE,map)
    colnames(MAPDATA)[1]="caldt"
    MAPRES=rbind(MAPRES,MAPDATA)
    
  }
  return(MAPRES)
  
}

cl=makeCluster(detectCores())
clusterEvalQ(cl,{
  library(lubridate)
  library(dplyr)
})

for(j in 1:length(Fundno)){
  print(j)
  x=monthlyMAP(FundnoPortnoMAP,Fundno = Fundno[j])
}

MAPDATA=parLapply(cl,as.list(Fundno),monthlyMAP,FundnoPortnoMAP=FundnoPortnoMAP)
stopCluster(cl)
MAPDATA=do.call(rbind,MAPDATA)
row.names(MAPDATA)=NULL

l=c("Date",l)
MAPDATA=set_variable_labels(MAPDATA, .labels = l[1:22])



write_dta(MAPDATA,"MonthlyFundnoPortnoMAP.dta")

# Cheking map at portno level

MonthlyFundnoPortnoMAP <- read_dta("MonthlyFundnoPortnoMAP.dta")



MonthlyPortnoMAP=MonthlyFundnoPortnoMAP%>%
  select(caldt,mgmt_cd,index_fund_flag,et_flag,retail_fund,inst_fund,open_to_inv,
         crsp_obj_cd,TName,FName,comp_cik,series_cik,FundId,wficn,crsp_portno)%>%distinct()


MonthlyPortnoMAP=MonthlyPortnoMAP%>%group_by(crsp_portno)%>%
  mutate(retail_fund=modef(retail_fund),inst_fund=modef(inst_fund),open_to_inv=modef(open_to_inv),
         mgmt_cd=modef(mgmt_cd),index_fund_flag=modef(index_fund_flag),
         et_flag=modef(et_flag),crsp_obj_cd=modef(crsp_obj_cd),TName=modef(TName),
         FName=modef(FName))%>%
  ungroup()%>%distinct()

ix=duplicated(MonthlyPortnoMAP)
MonthlyPortnoMAP=MonthlyPortnoMAP[!ix,]



ix=which(MonthlyPortnoMAP$comp_cik=="")
MonthlyPortnoMAP[ix,"comp_cik"]=NA

ix=which(MonthlyPortnoMAP$series_cik=="")
MonthlyPortnoMAP[ix,"series_cik"]=NA

ix=which(MonthlyPortnoMAP$FundId=="")
MonthlyPortnoMAP[ix,"FundId"]=NA

ix=which(MonthlyPortnoMAP$wficn=="")
MonthlyPortnoMAP[ix,"wficn"]=NA


MonthlyPortnoMAP[,"crsp_portno"]=as.numeric(MonthlyPortnoMAP$crsp_portno)
MonthlyPortnoMAP[,"wficn"]=as.numeric(MonthlyPortnoMAP$wficn)
MonthlyPortnoMAP[,"comp_cik"]=as.numeric(MonthlyPortnoMAP$comp_cik)




l1=c(l[1:10],l[13:17])

MonthlyPortnoMAP=set_variable_labels(MonthlyPortnoMAP,.labels =l1 )

write_dta(MonthlyPortnoMAP,"MonthlyPortnoMAP.dta")