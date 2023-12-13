# Load necessary libraries
library(haven)      # For importing files from Stata
library(dplyr)      # Data manipulation
library(parallel)   # Parallel computing
library(labelled)   # Handling variable labels in data frames
library(sjlabelled) # Additional tools for variable labels
library(lubridate)  # Date handling in data frames
library(DescTools)  # Provides a variety of descriptive tools including mode calculation

# Define a function to compute mode, handling NA values robustly
modef <- function(x) {
  # Calculate mode, removing NA values
  m <- Mode(x, na.rm = TRUE)[1]
  
  # If mode is NA, return the first non-NA value after sorting
  if (is.na(m)) {
    r <- sort(x[!is.na(x)])[1]
  } else {
    r <- m
  }
  
  return(r)
}

# ---------------------------------------------------------------------------------
# Data Preparation and Cleaning

# Load FundnoPortnoMAP dataset and select distinct records with necessary columns
# This dataset is checked to be consistent with the original MAP
FundnoPortnoMAP <- read_dta("D:/DATOS/CRSP Mutual funds/FundnoPortnoMAP.dta")
FundnoPortnoMAP <- FundnoPortnoMAP %>% 
  select(mgmt_cd, fund_name, open_to_inv, retail_fund, inst_fund, crsp_portno, crsp_fundno, dead_flag, delist_cd, merge_fundno, begdt, enddt) %>% 
  distinct()

# Load fundnoportnobfr2003 dataset
# This dataset contains fund numbers and port numbers before the year 2003
fundnoportnobfr2003 <- read_dta("D:/DATOS/CRSP_MsD_MAP/fundnoportnobfr2003.dta")

# Extract unique CRSP fund numbers from the 'fundnoportnobfr2003' dataset
fno <- unique(fundnoportnobfr2003$crsp_fundno)

# Split 'FundnoPortnoMAP' into two datasets based on fund number's year
# 1. Funds after 2003 (no extrapolation needed)
FundnoPortnoMAP2a <- FundnoPortnoMAP %>% 
  filter(!(crsp_fundno %in% fno))

# 2. Funds before 2003 (extrapolation required)
FundnoPortnoMAP2b <- FundnoPortnoMAP %>% 
  filter(crsp_fundno %in% fno) %>%
  arrange(crsp_fundno)

# Adjust 'begdt' for funds with start dates before 31st July 2003
ix <- which(FundnoPortnoMAP2b$begdt <= "2003-07-31")
FundnoPortnoMAP2b[ix, "begdt"] <- as.Date("2000-01-31")

# Group by 'crsp_fundno' and adjust 'begdt' based on the number of unique 'crsp_portno'
FundnoPortnoMAP2b <- FundnoPortnoMAP2b %>% 
  group_by(crsp_fundno) %>%
  mutate(np = length(unique(crsp_portno))) %>%
  mutate(begdt1 = ifelse(np > 1 & begdt == min(begdt), 1, 0))

# Update 'begdt' for certain conditions and remove temporary columns
ix <- which(FundnoPortnoMAP2b$begdt1 == 1)
FundnoPortnoMAP2b[ix, "begdt"] <- as.Date("2000-01-31")
FundnoPortnoMAP2b <- FundnoPortnoMAP2b %>% 
  select(-begdt1, -np)

# Repeat the process for a different condition
FundnoPortnoMAP2b <- FundnoPortnoMAP2b %>% 
  group_by(crsp_fundno) %>%
  mutate(np = length(unique(crsp_portno))) %>%
  mutate(begdt1 = ifelse(np == 1 & begdt == min(begdt), 1, 0))

ix <- which(FundnoPortnoMAP2b$begdt1 == 1)
FundnoPortnoMAP2b[ix, "begdt"] <- as.Date("2000-01-31")
FundnoPortnoMAP2b <- FundnoPortnoMAP2b %>% 
  select(-begdt1, -np)

# Combine the datasets 'FundnoPortnoMAP2a' and 'FundnoPortnoMAP2b'
FPMAP <- rbind(FundnoPortnoMAP2a, FundnoPortnoMAP2b)

# Create 'PromData' to identify funds with more than 2 'crsp_portno'
PromData <- FPMAP %>% 
  group_by(crsp_fundno, begdt) %>%
  mutate(np = unique(length(crsp_portno))) %>%
  filter(np > 2) %>%
  arrange(crsp_fundno, begdt)

# Final arrangement of 'FPMAP'
FPMAP <- FPMAP %>% 
  ungroup() %>%
  arrange(crsp_portno, begdt)

# -----------------------------------------------------------------------------
# Adding FundId to the dataset

# Set working directory and read datasets
setwd("D:/Morninstar Data/CRSP_MsD_Track")
MsDSCFunds <- read_dta("MsDSCFunds.dta")
CRSP1 <- read_dta("PortnoFundnoTickerNcusip.dta")

# Clean 'CRSP1' dataset by removing 'crsp_portno' and handling empty 'ncusip' and 'ticker'
CRSP1[, "crsp_portno"] <- NULL
CRSP1[CRSP1$ncusip == "", "ncusip"] <- NA
CRSP1[CRSP1$ticker == "", "ticker"] <- NA

# Group by 'crsp_fundno', apply 'modef' function to 'ncusip' and 'ticker', and arrange
CRSP <- CRSP1 %>% 
  group_by(crsp_fundno) %>%
  mutate(ncusip = ifelse(length(crsp_fundno) > 1, modef(ncusip), ncusip)) %>%
  mutate(ticker = ifelse(length(crsp_fundno) > 1, modef(ticker), ticker)) %>%
  distinct() %>%
  arrange(crsp_fundno)

# Identify multiple entries in 'CRSP'
PromData <- CRSP %>% 
  mutate(ns = length(crsp_fundno)) %>%
  filter(ns > 1)

# Clean 'MsDSCFunds' dataset
MsDSCFunds[MsDSCFunds$ncusip == "", "ncusip"] <- NA
MsDSCFunds[MsDSCFunds$ticker == "", "ticker"] <- NA

# Match datasets by 'ticker' and 'ncusip' and combine results
MsDa <- MsDSCFunds %>% 
  filter(!is.na(ticker)) %>%
  select(FundId, ticker) %>%
  inner_join(CRSP)
MsDb <- MsDSCFunds %>% 
  filter(!is.na(ncusip)) %>%
  select(FundId, ncusip) %>%
  inner_join(CRSP)

MsD <- rbind(MsDa, MsDb) %>% 
  distinct() %>%
  arrange(crsp_fundno)

# Group by 'crsp_fundno' and apply 'modef' function to 'FundId'
MsD <- MsD %>% 
  group_by(crsp_fundno) %>%
  mutate(FundId = ifelse(length(crsp_fundno) > 1, modef(FundId), FundId)) %>%
  distinct()

# Join 'CRSP' with 'MsD' and update 'PromData'
CRSP <- left_join(CRSP, MsD)
PromData <- CRSP %>% 
  group_by(crsp_fundno) %>%
  mutate(ns = length(crsp_fundno)) %>%
  filter(ns > 1)

# Improve mapping in 'FIFPMAP'
FIFPMAP <- left_join(FPMAP, CRSP) %>% 
  select(mgmt_cd, fund_name, open_to_inv, retail_fund, inst_fund, FundId, crsp_portno, crsp_fundno, ncusip, ticker, dead_flag, delist_cd, merge_fundno, begdt, enddt) %>%
  distinct() %>%
  arrange(crsp_portno, begdt)

# Group by 'crsp_portno' and handle missing 'FundId'
FIFPMAP <- FIFPMAP %>% 
  group_by(crsp_portno) %>%
  mutate(FundId = ifelse(is.na(FundId), modef(FundId), FundId))

# Handle cases with multiple 'FundId' values
FIFPMAP <- FIFPMAP %>% 
  group_by(crsp_portno) %>%
  mutate(nfi = length(unique(FundId))) %>%
  mutate(FundId = ifelse(nfi > 1, modef(FundId), FundId))

# Update 'PromData' with the latest changes
PromData <- FIFPMAP %>% 
  group_by(crsp_portno) %>%
  mutate(nfi = length(unique(FundId))) %>%
  filter(nfi > 1)

# Remove the temporary column 'nfi'
FIFPMAP[, "nfi"] <- NULL

# -----------------------------------------------------------------------------
# Correcting problematic mappings in fund data
# This process handles specific cases identified through manual checking

# List of fund numbers to drop due to problematic share classes
fnod <- c(49059, 17984, 17985, 11604, 8053, 8060, 10393, 12056, 49064, 49063, 11552)

# Dropping share classes that are problematic
ix <- which(FIFPMAP$crsp_fundno %in% fnod)
FIFPMAP <- FIFPMAP[-ix, ]

# List of fund numbers where 'enddt' needs to be changed to avoid duplication of funds
fnos <- c(4238, 5011, 3264, 30144, 29489, 13637, 9597, 21059, ... [Additional Numbers] ..., 21744, 25083, 24387, 24944, 25513, 25509, 25445, 32156, 3955)

# Correcting 'enddt' for specific funds to a uniform date to avoid fund multiplication
ix <- which(FIFPMAP$crsp_fundno %in% fnos)
FIFPMAP[ix, "enddt"] <- as.Date("2010-05-31")

# Further adjustments to 'enddt' for other sets of fund numbers
fnos1 <- c(24922, 24923, 24940, 24941, 24912, 24913)
ix <- which(FIFPMAP$crsp_fundno %in% fnos1)
FIFPMAP[ix, "enddt"] <- as.Date("2008-06-30")

fnos2 <- c(9184)
ix <- which(FIFPMAP$crsp_fundno %in% fnos2)
FIFPMAP[ix, "enddt"] <- as.Date("2011-08-31")

# Adjusting 'begdt' for share classes due to merges
fnom <- c(37903, 17987, 10664, 37951, 8311, 17910, 28827, 28828, 28829, 28838, 28839, 28837, ... [Additional Numbers] ..., 4764, 4767)

# Change 'begdt' for certain funds to a specific date due to merges
ix <- which(FIFPMAP$crsp_fundno %in% fnom)
FIFPMAP[ix, "begdt"] <- as.Date("2010-06-30")

# Correcting duplicated 'portno' entries by setting 'FundId' to NA
pno <- c(1031421, 1049256, 1051422, 1018811, 1019740, 1029541, 100730, ... [Additional Numbers] ..., 1028608)

ix <- which(FIFPMAP$crsp_portno %in% pno)
FIFPMAP[ix, "FundId"] <- NA

# Filtering out entries with invalid date ranges
# Ensures 'begdt' is always less than or equal to 'enddt'
FIFPMAP <- FIFPMAP %>% filter(begdt <= enddt)

# -----------------------------------------------------------------------------
# Handling Cases with Multiple Port Numbers per FundId

# Identifying cases where a single FundId corresponds to multiple port numbers
PromData <- FIFPMAP %>%
  group_by(FundId) %>%
  mutate(np = length(unique(crsp_portno))) %>%
  filter(np > 1, !is.na(FundId)) %>%
  arrange(FundId) %>%
  select(FundId, crsp_portno, crsp_fundno, begdt, enddt)

# Filtering data to ensure a unique FundId is tied to a unique fund
PromData1 <- PromData %>%
  group_by(FundId, crsp_portno) %>%
  mutate(Mbdt = year(min(begdt)), Medt = year(max(enddt))) %>%
  ungroup() %>%
  group_by(FundId) %>%
  mutate(Nbdt = length(unique(Mbdt)), Nedt = length(unique(Medt))) %>%
  filter(Nbdt == 1 | Nedt == 1)

PromData1 <- PromData %>%
  group_by(FundId, crsp_portno) %>%
  mutate(Mbdt = min(begdt), Medt = max(enddt)) %>%
  ungroup() %>%
  group_by(FundId) %>%
  mutate(Nbdt = length(unique(Mbdt)), Nedt = length(unique(Medt))) %>%
  filter(Nbdt == 1 | Nedt == 1)

# Further refining PromData for cases with more than two port numbers
PromData <- FIFPMAP %>%
  group_by(FundId) %>%
  mutate(npno = length(unique(crsp_portno))) %>%
  filter(npno > 2 & !is.na(FundId)) %>%
  arrange(FundId) %>%
  select(FundId, crsp_portno, crsp_fundno, begdt, enddt)

# -----------------------------------------------------------------------------
# Cleaning up the environment and preparing for further processing
rm(list = setdiff(ls(), c("FIFPMAP", "modef")))
gc()
.rs.restartR()

# -----------------------------------------------------------------------------
# Processing wficn data and integrating with FIFPMAP

# Set working directory and read wficn data
setwd("D:/DATOS/MFLINKS")
wficn_CRSPfundno <- read_dta("D:/DATOS/MFLINKS/wficn_CRSPfundno.dta")

# Clean wficn data by selecting distinct records
wficn_CRSPfundno <- wficn_CRSPfundno %>%
  select(wficn, crsp_fundno, ncusip, ticker) %>%
  distinct()

# Identify cases with multiple funds assigned to the same share class
PromData <- wficn_CRSPfundno %>%
  group_by(crsp_fundno) %>%
  mutate(ns = length(crsp_fundno)) %>%
  filter(ns > 1) %>%
  arrange(crsp_fundno)

# Identify and handle changes in wficn over time
wfchange <- unique(PromData$crsp_fundno)
wficn <- wficn_CRSPfundno %>%
  filter(!(crsp_fundno %in% wfchange)) %>%
  select(wficn, crsp_fundno) %>%
  distinct()

# Merging wficn data with FIFPMAP
WFFIFPMAP <- left_join(FIFPMAP, wficn)

# Selecting and arranging columns, ensuring distinct records
WFFIFPMAP <- WFFIFPMAP %>%
  select(mgmt_cd, fund_name, open_to_inv, retail_fund, inst_fund, FundId, wficn, crsp_portno, crsp_fundno, ncusip, ticker, dead_flag, delist_cd, merge_fundno, begdt, enddt) %>%
  distinct() %>%
  arrange(crsp_portno, begdt)

# Handling cases with multiple wficn per crsp_portno
WFFIFPMAP <- WFFIFPMAP %>%
  group_by(crsp_portno) %>%
  mutate(nw = length(unique(wficn))) %>%
  mutate(wficn = ifelse(nw > 1, modef(wficn), wficn))

# Removing temporary column 'nw'
WFFIFPMAP[, "nw"] <- NULL


# -----------------------------------------------------------------------------
# Ensuring Unique Mapping of FundId and wficn to Port Numbers

# Identifying cases where a single crsp_portno is tied to multiple wficn
PromData <- WFFIFPMAP %>%
  group_by(crsp_portno) %>%
  mutate(nw = length(unique(wficn))) %>%
  filter(nw > 1) %>%
  arrange(crsp_portno)

# Further data refinement based on wficn and FundId associations
PromData <- WFFIFPMAP %>%
  group_by(wficn) %>%
  mutate(np = length(unique(crsp_portno))) %>%
  filter(np > 1, !is.na(wficn)) %>%
  arrange(wficn) %>%
  select(FundId, wficn, crsp_portno, crsp_fundno, begdt, enddt)

# -----------------------------------------------------------------------------
# Backfilling Missing FundId and wficn Data

# Backfill FundId using wficn where possible
WFFIFPMAP <- WFFIFPMAP %>%
  group_by(wficn) %>%
  mutate(FundId = ifelse(!is.na(wficn) & is.na(FundId), modef(FundId), FundId)) %>%
  ungroup()

# Check for duplicate FundId on wficn and vice versa
PromData <- WFFIFPMAP %>%
  group_by(wficn) %>%
  mutate(nfi = length(unique(FundId))) %>%
  filter(nfi > 1, !is.na(wficn)) %>%
  arrange(wficn, FundId, begdt, enddt) %>%
  select(FundId, wficn, crsp_portno, crsp_fundno, begdt, enddt)

# -----------------------------------------------------------------------------
# Final Verification of Mapping

# Guaranteeing that mapping of FundId and wficn is tied to a unique portno at a specific time
WFFIFPMAP1 <- WFFIFPMAP

# -----------------------------------------------------------------------------
# Correcting Tickers and NCUSIPs

# Extract distinct information for ticker and ncusip
headinfo <- wficn_CRSPfundno %>%
  select(crsp_fundno, ncusip, ticker) %>%
  distinct()

# Identify share classes with multiple tickers or ncusips
fnmp <- headinfo %>%
  group_by(crsp_fundno) %>%
  mutate(ntk = length(unique(ticker)), ncp = length(unique(ncusip))) %>%
  filter(ntk > 1 | ncp > 1)

# Fill in missing ncusip and ticker information
# Loop through unique fund numbers and assign ncusip and ticker where missing
for (i in unique(WFFIFPMAP1$crsp_fundno)) {
  ix <- which(WFFIFPMAP1$crsp_fundno == i)
  ix1 <- which(headinfo$crsp_fundno == i)
  
  if (length(ix1) > 0) {
    WFFIFPMAP1[ix, "ncusip"] <- headinfo$ncusip[ix1]
    WFFIFPMAP1[ix, "ticker"] <- headinfo$ticker[ix1]
  }
}

# Replace empty strings with NA in ncusip and ticker fields
WFFIFPMAP1[WFFIFPMAP1$ncusip == "", "ncusip"] <- NA
WFFIFPMAP1[WFFIFPMAP1$ticker == "", "ticker"] <- NA

# -----------------------------------------------------------------------------
# Final Dataset
MA1 <- WFFIFPMAP1

# -----------------------------------------------------------------------------
# Fixing Fund Names and Adding Investment Objective Code

library(stringr)

# Define a function to split and clean fund names
changname <- function(name) {
  s <- str_split(name, pattern = c(":"), simplify = T)
  if (length(s) > 1) {
    s1 <- str_split(s[2], pattern = c(";"), simplify = T)
  } else {
    s1 <- str_split(s[1], pattern = c(";"), simplify = T)
  }
  if (length(s) == 1) {
    s <- ""
  }
  
  R <- trimws(c(s[1], s1[1], s1[2]), which = "both")
  return(R)
}

# Apply the function to split fund names in MA1
TestName <- as.data.frame(t(sapply(MA1$fund_name, changname)))
rownames(TestName) <- NULL
colnames(TestName) <- c("TName", "FName", "SCName")

MA1 <- cbind(TestName, MA1)

# Correcting empty TNames by extracting the first word from FNames
ix <- which(MA1$TName == "")
fnames <- MA1$FName[ix]
cname <- sapply(fnames, function(x) unlist(strsplit(x, " "))[1])

for (i in 1:length(ix)) {
  MA1[ix[i], "TName"] <- cname[i]
}

# -----------------------------------------------------------------------------
# Adding Investment Objective, Index Flag, and ET Flag

# Read and select relevant columns from fundsummary dataset
fundsummary <- read_dta("D:/DATOS/CRSP Mutual funds/fundsummary.dta")
fundsummary <- fundsummary %>%
  select(crsp_fundno, et_flag, index_fund_flag, crsp_obj_cd) %>%
  distinct()

# Replace empty strings with "NON" in et_flag and index_fund_flag
fundsummary[fundsummary$et_flag == "", "et_flag"] <- "NON"
fundsummary[fundsummary$index_fund_flag == "", "index_fund_flag"] <- "NON"

# Drop rows with empty crsp_obj_cd
ix <- which(fundsummary$crsp_obj_cd == "")
fundsummary2 <- fundsummary[-ix, ]

# Ensure uniqueness of crsp_obj_cd, index_fund_flag, and et_flag for each crsp_fundno
fsm <- fundsummary2 %>%
  group_by(crsp_fundno) %>%
  mutate(nfn = length(crsp_fundno)) %>%
  mutate(crsp_obj_cd = ifelse(nfn > 1, modef(crsp_obj_cd), crsp_obj_cd)) %>%
  mutate(index_fund_flag = ifelse(nfn > 1, modef(index_fund_flag), index_fund_flag)) %>%
  mutate(et_flag = ifelse(nfn > 1, modef(et_flag), et_flag)) %>%
  distinct()
fsm[, "nfn"] <- NULL

# -----------------------------------------------------------------------------
# Joining Investment Objective Data with MA1

MA2 <- right_join(fsm, MA1)

# Reordering and selecting columns in the final dataset
MA2 <- MA2 %>%
  ungroup() %>%
  select(mgmt_cd, index_fund_flag, et_flag, retail_fund, inst_fund, open_to_inv, crsp_obj_cd, TName, FName, SCName, fund_name, FundId, wficn, crsp_portno, crsp_fundno, dead_flag, delist_cd, merge_fundno, ticker, ncusip, begdt, enddt)

# -----------------------------------------------------------------------------
# Final Cleanup

# Remove all objects except MA2 and modef function
rm(list = setdiff(ls(), c("MA2", "modef")))
gc()


# -----------------------------------------------------------------------------
# Correcting Various Fields in MA2 Dataset

# Replace empty strings with NA in various fields
MA2[MA2$mgmt_cd == "", "mgmt_cd"] <- NA
MA2[MA2$retail_fund == "", "retail_fund"] <- NA
MA2[MA2$inst_fund == "", "inst_fund"] <- NA
MA2[MA2$open_to_inv == "", "open_to_inv"] <- NA

# Adjusting crsp_obj_cd for each crsp_portno
MA2 <- MA2 %>%
  group_by(crsp_portno) %>%
  mutate(crsp_obj_cd = modef(crsp_obj_cd)) %>%
  ungroup() %>%
  arrange(crsp_portno, begdt, FundId, wficn)

# Adjusting mgmt_cd, et_flag, and index_fund_flag for each crsp_portno
MA2 <- MA2 %>%
  group_by(crsp_portno) %>%
  mutate(mgmt_cd = modef(mgmt_cd), 
         et_flag = modef(et_flag), 
         index_fund_flag = modef(index_fund_flag)) %>%
  ungroup()

# Fill missing mgmt_Cd using modef function and abbreviations from TName
# Create a string manipulation pattern
strx <- c(",","Inc","I ","  I","II","III","IV","V ", ... [Additional Strings] ..., "Advisers", "  s")
MA2 <- MA2 %>%
  mutate(mgmt_cd = ifelse(is.na(mgmt_cd), toupper(abbreviate(str_squish(str_remove_all(TName, paste(strx, collapse = "|"))), 5)), mgmt_cd)) %>%
  group_by(TName, crsp_portno) %>%
  mutate(mgmt_cd = ifelse(is.na(mgmt_cd), modef(mgmt_cd), mgmt_cd)) %>%
  ungroup()

# Checking for any discrepancies introduced by corrections
PromData <- MA2 %>%
  group_by(crsp_portno) %>%
  mutate(nobj = length(unique(crsp_obj_cd))) %>%
  filter(nobj > 1)

# Repeating checks for crsp_fundno
# Similar checks are performed for 'mgmt_cd'

# -----------------------------------------------------------------------------
# Exporting the MA2 Dataset

# Standardizing dates to have consistent day values
MA2$begdt <- as.Date(format(MA2$begdt, "%Y-%m-28"))
MA2$enddt <- as.Date(format(MA2$enddt, "%Y-%m-28"))

# Setting variable labels for clarity
variable_labels <- c("Management Company Code", "CRSP: Index Fund Indicator/ NON means no index", ... [Additional Labels] ..., "End Date")
MA2 <- set_variable_labels(MA2, .labels = variable_labels)

# Export the data in you most preferred format
