# Load necessary libraries
library(haven)     # For working with Stata files
library(dplyr)     # Data manipulation and transformation
library(tidyr)     # Data tidying
library(labelled)  # Handling variable labels within a data frame
library(sjlabelled) # Additional tools for handling variable labels
library(DescTools) # Provides a variety of tools for data processing, including mode calculation

# Define a function to calculate the mode, robust to NA values
modeA <- function(x) {
  m <- Mode(x, na.rm = TRUE)[1]
  if (is.na(m)) {
    r <- sort(x[which(!is.na(x))])[1]
  } else {
    r <- m
  }
  return(r)
}

# Import equity stock prices data and map by PERMNO (Permanent Number)
# The data comes from CRSP and focuses on price information, which is crucial for calculating value-weights
# Stocks without pricing information are considered missing and treated as non-reported
# It's important to use PERMNO for stock tracking due to changes in tickers and NCUSIPs over time
QuarterlyStockBAR <- read_dta("D:/DATOS/CRSP_STOCK/QuarterlyStockBAR.dta")

# Selecting relevant columns from QuarterlyStockBAR
# Includes date (caldt), PERMNO (Permanent Number), NCUSIP, TICKER, SHROUT (Shares Outstanding), and PRC (Price)
QuarterlyStockBAR <- QuarterlyStockBAR %>%
  select(caldt, PERMNO, NCUSIP, TICKER, SHROUT, PRC)


# Define the Htransform function for enhancing mutual fund holdings data
Htransform=function(y,QuarterlyStockBAR){
  tryCatch({
    
    
    setwd("D:/DATOS/Mutual Fund Holdings/Both/MixHoldings")
    # kEEP THE LAST QUARTER OF pRE-YEAR  
    pre=read_dta(paste("MFHoldings_",y-1,".dta",sep=""))
    pre=pre%>%filter(caldt>paste(y-1,"09","28",sep="-"))
    # Keep the entire Year of current
    curr=read_dta(paste("MFHoldings_",y,".dta",sep=""))
    # Keep the First Quarter of post-year
    pos=read_dta(paste("MFHoldings_",y+1,".dta",sep=""))
    pos=pos%>%filter(caldt<paste(y+1,"06","28",sep="-"))
    
    # Combine data from different years to capture Delta Holdings (First Quarter and last)
    data=rbind(pre,curr,pos)
    
    npre=nrow(pre); npo=nrow(pos);ncu=nrow(curr)
    # Overwrite heavy object with light objects to release memory
    pre=NULL; curr=NULL; pos=NULL; 
    rm(list=c("pre","curr","pos"))
    data=data%>%arrange(ID,Quarter) # Organize by Fund to identify changes in holdings (the data is compiled make organization through date)
    #################################################################
    # We need to complete holdings (Holdings adjustment where we have prices on equity)
    # 1) We need to add prices to holdings 
    # 2) We need to use a better identifier to stocks (PERMNO)
    
    # Firsst I keep Usable or workable portfolio holdings
    data[,"PERMNO"]=NULL
    
    # I keep holdings that are identifiable by ticker or NCUSIP (at least with one I can match stock prices)
    data=data%>%arrange(Quarter,ID,TICKER)%>%distinct()%>%ungroup()%>%
      mutate(NCUSIP=CUSIP)%>%
      filter(!(TICKER==""| is.na(TICKER)) | !(NCUSIP==""| is.na(NCUSIP)))
    
    
    # Drop Duplicated Holdings: Bad Reports
    ix=duplicated(data[,c("caldt","ID","TICKER","NCUSIP")])
    ix=which(ix==T)
    if(length(ix)>0){
      data=data[-ix,]
    }
    
    
    
    # Match by Ticker: cORRECTION of ticker
    MFT=data # Holdings to match by TICKER
    # Drop ticker that are non-identified: aVOID DUPLICATED MERGE
    ix=which(MFT$TICKER==""| is.na(MFT$TICKER))
    if(length(ix)>0){
      MFT=MFT[-ix,]
    }
    
    # Duplicated tickers on Holdings: Bad Reports
    ix=duplicated(MFT[,c("caldt","ID","TICKER")])
    ix=which(ix==T)
    if(length(ix)>0){
      MFT=MFT[-ix,]
    }
    
    
    
    
    # Match by ncusip: Correction of CUSIP Holdings
    MFNC=data # Holdings to match by TICKER
    # Drop ticker that are non-identified: aVOID DUPLICATED MERGE
    ix=which(MFNC$NCUSIP==""| is.na(MFNC$NCUSIP))
    if(length(ix)>0){
      MFNC=MFNC[-ix,] 
    }
    # Duplicated tickers on Holdings: Bad Reports
    ix=duplicated(MFNC[,c("caldt","ID","NCUSIP")])
    ix=which(ix==T)
    if(length(ix)>0){
      MFNC=MFNC[-ix,]
    }
    
    
    
    ###############################################################################
    # Merge Quarterly stock information: TICKER and CUSIP
    ##############################################################################
    
    # Merging Quarterly Stock: tICKER
    QS1=QuarterlyStockBAR; QS1[,c("NCUSIP","CUSIP")]=NULL;QS1=distinct(QS1)
    ix=duplicated(QS1[,c("caldt","PERMNO","TICKER")])
    ix=which(ix==T)
    if(length(ix)>0){
      QS1=QS1[-ix,]
    }
    
    MFT1=inner_join(MFT,QS1)
    
    # Merging Quarterly Stock: NCUSIP
    QS1=QuarterlyStockBAR; QS1[,c("CUSIP","TICKER")]=NULL;QS1=distinct(QS1)
    ix=duplicated(QS1[,c("caldt","PERMNO","NCUSIP")])
    ix=which(ix==T)
    if(length(ix)>0){
      QS1=QS1[-ix,]
    }
    
    MFNC1=inner_join(MFNC,QS1)
    
    MF=distinct(rbind(MFT1,MFNC1))
    MF=MF%>%arrange(caldt,ID,PERMNO)
    
    ix=duplicated(MF[,c("caldt","ID","PERMNO")])
    ix=which(ix==T)
    if(length(ix)>0){
      MF=MF[-ix,]
      
    }
    
    data=MF
    # Overwrite object to save memory space (ONLY KEEP data)
    MFT=NULL; MFNC=NULL; MFT1=NULL; MFNC1= NULL; MF=NULL
    
    data=data%>%
      select(caldt, ID, TName, FName, FundId, wficn, Fundno, crsp_portno, Source,
             PERMNO, TICKER, NCUSIP, StkName, SHROUT, Shares, PRC)
    
    
    
    
    #################################################################  
    # We need to complete holdings to identify creation and liquidation through stocks
    
    data= data %>% group_by(ID) %>% #Within each fund, 
      complete(caldt,PERMNO)%>% #turns implicit missing values into explicit missing values. Generate all possible combinations of caldt and PERMNO that occur for that fund
      ungroup() %>% arrange(PERMNO, ID, caldt) # Now data has a different arrangement (need it to lags and leads)
    
    
    # NOTE (ASSUMPTION) : When a stock dissapear and appear in the nex quarter,
    # We assume the missing report due to impossibility to match prices instead of a transaction
    # An initiated purchase or liquidate sale only is considered when at least for two consecutive quarter the stock dissappear 
    
    data=data %>% 
      group_by(PERMNO,ID) %>% 
      mutate(lagShares=lag(Shares, 1),
             leadShares=lead(Shares, 1))%>%ungroup()
    
    # we assume no changes in share holdings in this scenario 
    
    data=data%>%
      mutate(Shares=ifelse(is.na(Shares) & !is.na(lagShares) & !is.na(leadShares),
                           lagShares,
                           Shares))
    
    data[,c("lagShares","leadShares")]=NULL
    
    
    
    # We assume Shares equal to NA, correspond to zero holdings (The stock disappear from portfolio)
    
    
    data=data%>%
      mutate(Shares=ifelse(is.na(Shares), 0, Shares))
    
    
    data=data %>% 
      group_by(PERMNO,ID) %>% 
      mutate(lagShares=lag(Shares, 1),
             leadShares=lead(Shares, 1))%>% ungroup()
    
    
    data=data %>% 
      group_by(PERMNO,ID) %>% 
      mutate(lagShares=ifelse(is.na(lagShares),0, lagShares),
             leadShares=ifelse(is.na(leadShares), 0, leadShares))%>% ungroup()
    
    ##########################################################################
    #         Creating the variables  for transactions
    #########################################################################
    
    # changes in share holdings
    data=data %>% 
      mutate(DtShares=Shares-lagShares)
    
    # Indicator Variables : Transaction Types
    data=data%>%mutate(Purchase=ifelse(DtShares > 0, 1, 0),
                       Sales=ifelse(DtShares < 0, 1, 0),
                       Creation=ifelse(Shares > 0 & lagShares==0, 1, 0),
                       Liquidation=ifelse(Shares == 0 & lagShares > 0, 1, 0))
    
    # Clean portfolio holdings from irrelevant fillings
    
    data=data%>%
      filter(Shares>0 | (Shares==0 & Liquidation==1))
    
    
    data=data%>%
      select(caldt,ID,FundId,wficn, Fundno, crsp_portno, 
             TName, FName, Source,
             PERMNO, TICKER, NCUSIP, StkName, Shares, lagShares, leadShares,
             DtShares, Purchase, Creation, Sales, Liquidation)%>%distinct()
    
    
    
    data=data%>%
      filter(caldt > paste(y-1,"12","28",sep="-") & caldt < paste(y+1,"03","28",sep="-"))
    
    
    # Fill complete observations where informative information is missing
    
    
    data=data%>%group_by(PERMNO)%>%
      mutate(TICKER=ifelse(!is.na(TICKER), TICKER, modeA(TICKER)),
             NCUSIP=ifelse(!is.na(NCUSIP), NCUSIP, modeA(NCUSIP)),
             StkName=ifelse(!is.na(StkName), StkName, modeA(StkName)))%>%ungroup()
    
    
    data=data%>%group_by(caldt,ID)%>%
      mutate(FundId=ifelse(!is.na(FundId), FundId, modeA(FundId)),
             wficn=ifelse(!is.na(wficn), wficn, modeA(wficn)),
             Fundno=ifelse(!is.na(Fundno), Fundno, modeA(Fundno)),
             crsp_portno=ifelse(!is.na(crsp_portno), crsp_portno, modeA(crsp_portno)),
             TName=ifelse(!is.na(TName), TName, modeA(TName)),
             FName=ifelse(!is.na(FName), FName, modeA(FName)),
             Source=ifelse(!is.na(Source), Source, modeA(Source)))%>%ungroup()
    
    data=data%>%arrange(caldt,ID,PERMNO)
    
    
    L=c("Current Date","Fund Id","Fund Id: MsD","Fund Id: Wharton","Fund Id: Thomson Reuters","Fund Id: CRSP",
        "Family Name", " Fund Name", "PH Source", "CRSP Stock Unique Id", "Ticker", "Ncusip", "Stock Name: PH",
        "Number of Current Shares",
        "Number of Shares  Held in Previous Quarter",
        "Number Of Shares Held in Upcoming Quarter",
        "Changes in Held Shares: Delta Shares",
        "Indicator Variable for a Purchase Transaction",
        "Indicator Variable for a Purchase Transaction that Creates Holdings",
        "Indicator Variable for a Sales Transaction",
        "Indicator Variable for a Sales Transaction that Eliminates Holdings")
    
    data=set_variable_labels(data,.labels = L)
    
    # Generate output with new Holdings: Enhanced Equity Mutual Fund Holdings  
    write_dta(data,paste("EMFHoldings_",y,".dta",sep=""))
    
  },error=function(e) NULL)
  
  
  
}

Y=seq(2021,2022,1)

data=lapply(as.list(Y),Htransform, QuarterlyStockBAR=QuarterlyStockBAR)


