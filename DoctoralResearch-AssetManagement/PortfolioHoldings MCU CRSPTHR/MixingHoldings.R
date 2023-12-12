# Load necessary libraries
library(haven)       # Library to work with stata files
library(dplyr)       # Library for data processing
library(parallel)    # Parallel computing (work by cores)
library(labelled)    # label your variables
library(sjlabelled)  # Label your variables
library(lubridate)   # work with dates
library(DescTools)   # Different tools like mode

# Define a function to calculate the mode, robust to NA data
modef <- function(x) {
  m <- Mode(x, na.rm = TRUE)[1]
  if (is.na(m)) {
    r <- sort(x[which(!is.na(x))])[1]
  } else {
    r <- m
  }
  return(r)
}

# Define a function to calculate the sum, handling NA values appropriately
suma <- function(df) {
  if (all(is.na(df))) {
    sum <- NA
  } else {    
    sum <- sum(df, na.rm = TRUE)
  }
  return(sum)
}

# Function to build the most comprehensive and up-to-date mutual fund holdings
# Following the criteria outlined in Chernenko et al., (2020)
FundData <- function(wn, scrsp, str) {
  id1 <- sort(unique(scrsp$ID)) # Funds in CRSP
  id2 <- sort(unique(str$ID))   # Funds in TR
  
  ccrsp <- filter(scrsp, ID == wn)
  ctr <- filter(str, ID == wn)
  
  # Identify the source with more recent data
  datecrsp <- max(ccrsp$caldt, na.rm = TRUE)
  datetr <- max(ctr$caldt, na.rm = TRUE)
  
  ccrsp <- ccrsp[which(ccrsp$caldt == datecrsp),] # Keep the updated date from CRSP
  ctr <- ctr[which(ctr$caldt == datetr),]         # Keep the updated date from TR
  
  # Keep the database with more holdings
  nhcrsp <- nrow(ccrsp)
  nhtr <- nrow(ctr)
  
  # Making the selection process following Chernenko et al., 2020
  if ((wn %in% id1) & (wn %in% id2)) {
    # If fund's holdings are reported in both databases, keep the more recent-comprehensive data
    if (datecrsp > datetr) {
      data <- ccrsp
    } else if (datecrsp < datetr) {
      data <- ctr
    } else {
      # If both are reported on the same date
      if (nhcrsp > nhtr) {
        data <- ccrsp
      } else if (nhcrsp < nhtr) {
        data <- ctr
      } else { 
        data <- ctr # Default to Thomson Reuters
      }
    }
  } else if ((wn %in% id1) & !(wn %in% id2)) {
    data <- ccrsp # Only reported in CRSP
  } else {
    data <- ctr   # Only reported in Thomson Reuters
  }
  
  return(data)
}

# Function to run FundData for a given quarter
QData <- function(q, CRSP, TR) {
  scrsp <- filter(CRSP, Quarter == q)
  str <- filter(TR, Quarter == q)
  
  # Identify the fund IDs
  id1 <- sort(unique(scrsp$ID))
  id2 <- sort(unique(str$ID))
  id <- sort(unique(c(id1, id2)))
  
  # Mix the data for a given quarter and fund ID
  FData <- lapply(as.list(id), FundData, scrsp = scrsp, str = str)
  FData1 <- do.call(rbind, FData)
  
  FData1[, "caldt"] <- as.Date(max(FData1$caldt, na.rm = TRUE))
  FData1 <- FData1 %>% arrange(wficn)
  
  return(FData1)
}



# Define the MFHoldings function to process mutual fund holdings for a given year
MFHoldings <- function(y) {
  tryCatch({
    # Set the working directory
    setwd("D:/DATOS/Mutual Fund Holdings/Both")
    
    # Import Links to match CRSP and Thomson Reuters data
    MonthlyPortnoMAP <- read_dta("D:/DATOS/CRSP Mutual funds/MonthlyPortnoMAP.dta")
    ix <- which(MonthlyPortnoMAP$FundId == "")
    MonthlyPortnoMAP[ix, "FundId"] <- NA
    
    # Preparing MonthlyPortnoMAP
    MonthlyPortnoMAP <- MonthlyPortnoMAP %>%
      mutate(ID = ifelse(!is.na(FundId), FundId, ifelse(!is.na(wficn), paste("NA", wficn, sep=""), paste("NA", crsp_portno, sep="")))) %>%
      mutate(Year = year(caldt)) %>%
      filter(Year == y) %>%
      select(caldt, ID, TName, FName, FundId, wficn, crsp_portno) %>%
      distinct()
    
    # Preparing Thomson Reuters link data
    trlink <- read_dta("D:/DATOS/MFLINKS/wficn_TRfundno.dta")
    trlink <- trlink %>%
      mutate(Year = year(rdate)) %>%
      filter(Year == y) %>%
      select(wficn, fundno) %>%
      distinct() %>%
      filter(!is.na(wficn)) %>%
      group_by(wficn) %>%
      mutate(fundno = modef(fundno)) %>%
      distinct()
    Link <- left_join(MonthlyPortnoMAP, trlink)
    
    # Read and prepare CRSP data
    dircrsp <- paste("D:/DATOS/Mutual Fund Holdings/CRSP/crsp_mfholdings_", y, ".dta", sep="")
    crsp <- read_dta(dircrsp) %>%
      select(report_dt, crsp_portno, security_name, permno, permco, ticker, cusip, nbr_shares) %>%
      distinct() %>%
      rename(caldt = report_dt) %>%
      inner_join(Link) %>%
      mutate(Quarter = quarters(caldt), Source = "CRSP") %>%
      select(Quarter, caldt, ID, TName, FName, FundId, wficn, fundno, crsp_portno, Source, security_name, permno, permco, ticker, cusip, nbr_shares)
    
    # Read and prepare Thomson Reuters data
    dirtr <- paste("D:/DATOS/Mutual Fund Holdings/Thomson Reuters s12/S12_", y, ".dta", sep="")
    S12 <- read_dta(dirtr) %>%
      mutate(permno = NA, permco = NA, Source = "ThRs") %>%
      select(rdate, Source, fundno, fundname, stkname, permno, permco, ticker, cusip, shares) %>%
      distinct() %>%
      rename(caldt = rdate) %>%
      inner_join(Link) %>%
      mutate(Quarter = quarters(caldt)) %>%
      select(Quarter, caldt, ID, TName, FName, FundId, wficn, fundno, crsp_portno, Source, stkname, permno, permco, ticker, cusip, shares) %>%
      distinct()
    
    # Homogenize variable names in both datasets
    colnames(crsp) <- c("Quarter", "caldt", "ID", "TName", "FName", "FundId", "wficn", "Fundno", "crsp_portno", "Source", "StkName", "PERMNO", "PERMCO", "TICKER", "CUSIP", "Shares")
    colnames(S12) <- colnames(crsp)
    
    # Identify quarters to process
    Q1 <- unique(crsp$Quarter)
    Q2 <- unique(S12$Quarter)
    Q <- sort(unique(c(Q1, Q2)))
    
    # Process data for each quarter
    Data <- lapply(as.list(Q[2]), QData, CRSP = crsp, TR = S12)
    Data <- do.call(rbind, Data) %>%
      arrange(Quarter, wficn) %>%
      set_variable_labels(.labels = c("Quarter", "Date", "ID Fund", "Trust Name", "Fund Name", "FundId", "Wharton Fund Identifier", "Thomson Fund Identifier Number", "CRSP Fund Identifier Number", "Database Source", "Stock Name", "CRSP Permanent Number: Security", "CRSP Permanent Number: Company", "Ticker Symbol", "Cusip Number", "Number of Shares Held Quarter-End"))
    
    # Export the processed data
    setwd("D:/DATOS/Mutual Fund Holdings/Both")
    write_dta(Data, paste("MFHoldings_", y, ".dta", sep=""))
    
  }, error = function(e) NULL)
}

# Process data for specified years
Y <- seq(2021, 2022, 1)
Data <- lapply(Y, MFHoldings)

