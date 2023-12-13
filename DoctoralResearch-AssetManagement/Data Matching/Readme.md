# Instruccions for the Code
## **FundnoPortnoMap Explanation**:
  - **Purpose**: The `FundnoPortnoMap` file, reported by CRSP, is a key resource that maps each `crsp_portno` (Portfolio Identifier) to `crsp_fundno` (Share Class Identifier). This mapping is crucial for navigating the CRSP mutual fund universe. For a detailed understanding of CRSP's data structure, consult the [CRSP Mutual Fund Database Guide](https://wrds-www.wharton.upenn.edu/documents/410/CRSP_MFDB_Guide.pdf).
  
  - **Context**: In the mutual fund market, funds are typically offered to investors as whole portfolios and individual share classes. These share classes represent parts of the same portfolio but differ primarily in fee structures. For example, a portfolio might yield a 10% gross return, but the net return for investors varies across different share classes due to varying fees linked to liquidity needs.

  - **Market Dynamics**: Investors in the market trade place orders for specific share classes, not entire portfolios. Distinct TICKERS and CUSIPS identify each share class. However, these identifiers can change over time, both between and within funds, posing a challenge for consistent tracking.

  - **CRSP's Unique Identifier**: To address this, CRSP provides `crsp_fundno` as a unique identifier for each share class, alongside TICKERS and CUSIPS. This system facilitates accurate and consistent tracking of share classes over time despite changes in their identifiers.

The file provided by CRSP contains various columns, each representing specific data points:

- `crsp_portno`: Portfolio Identifier (ID)
- `crsp_fundno`: Share Class Identifier (ID)
- `begdt`: Beginning Date of the mapping period
- `enddt`: End Date of the mapping period
- `ncusip`: CUSIP (Committee on Uniform Securities Identification Procedures) number
- `merge_fundno`: Share Class ID that acquires or merges with another

## **fundnoportnobfr2003 Explanation**:

- **Mapping Challenge**: A significant challenge with the tracking file from CRSP, which maps `crsp_portno` to `crsp_fundno`, is that this mapping only exists post-2003. While this is sufficient for analyses post-July 2003, it poses issues for studies requiring data from earlier periods.

- **Overcoming the Challenge**: To mitigate this limitation, one must identify `crsp_fundno` reporting information before this date. This process involves checking the summary file for earlier dates and retaining the relevant `crsp_fundno`.

- **Creating `fundnoportnobfr2003`**: The `fundnoportnobfr2003` file or object can be created following the above procedure. This serves as a dataset of fund identifiers that require mapping corrections for dates before 2003. This file is essential for researchers needing comprehensive historical analysis.

## **MsDSCFunds Explanation**:

### Overview of Morningstar Direct Data Mapping

- **Fund Classification Differences**: Morningstar Direct, unlike CRSP, has a more granular approach to classifying funds. For instance, consider a portfolio with four share classes (A, B, C, D). While CRSP might view all these share classes as part of a single fund, Morningstar could classify them into two distinct funds: (A, C) as one and (B, D) as another.

### Research Focus

- **Portfolio-Level Analysis**: My research emphasizes transaction analysis at the portfolio level. Even when Morningstar classifies multiple funds under the same portfolio, my analysis treats them as a single fund. This approach may lead to encountering two distinct funds with the same portfolio in Morningstar's data.

### Data Cleaning and Matching

- **FundId and Share Class Identification**: In Morningstar, `FundId` is used to identify a fund. Similar to CRSP, different share classes within the same `FundId` can be distinguished using TICKERS and CUSIPs. However, it’s important to remember that Morningstar's aggregation approach differs from CRSP's methodology.

- **Historical Data Limitations**: When extracting data from Morningstar, be aware that TICKER and CUSIP information is not historical but reflects the status at the download time. This aspect poses a challenge for historical analysis and mapping.

### Challenges in Mapping CRSP with Morningstar

- **Key Identifiers**: The primary challenge in aligning CRSP data with Morningstar is the varying identification codes for funds (portfolios) across these platforms. The mapping pivots on TICKERS and CUSIPs, as these are the standard identifiers for share classes across both providers.

- **Handling Historical Variability and Gaps**: The historical changes in TICKERS and CUSIPs, and instances where share classes have corresponding `FundId` and `SCId` (Share Class Identifier in Morningstar) but lack TICKER or CUSIP information, present significant mapping challenges. In such cases, manual searches may be required to fill gaps, and unmapped funds may need to be excluded.

- **Recycling of TICKERS and CUSIPs**: There are instances where TICKERS and CUSIPs are associated with more than one `FundId`, indicating a share class belonging to multiple funds. In such cases, this ambiguous information should be dropped, as accurate mapping is not feasible.

### Final Structure

- **Mapping File Format**: This process's final output file is structured as `FundId | TICKER | CUSIP`. This format represents the culmination of the mapping information derived from Morningstar.

## wficn_CRSPfundno Explanation

### Overview of WRDS Data Mapping

- **CRSP and Thomson Reuter's Mapping**: The `wficn_CRSPfundno` dataset, provided by WRDS, is crucial in mapping CRSP data with Thomson Reuters information. This mapping is facilitated through a file known as MFLINKS, which effectively links about 98% of domestic equity funds in CRSP to Thomson Reuters.

- **Wharton Financial Institution Center Number (WFICN)**: The mapping uses a common identifier known as the Wharton Financial Institution Center Number (WFICN) to correlate mutual fund identifiers between CRSP and Thomson Reuters.

### **Importance in Mutual Fund Research**:

- **Portfolio Holdings Data**: For mutual fund research, particularly for data before 2010, Thomson Reuters is a valuable source of portfolio holdings information, which might not be available in CRSP. To integrate this holdings data into your database, mapping using the WFICN, associated with `crsp_portnos` and `FundId`, is essential.

### Mapping Strategies

- **Direct and Indirect Mapping Options**:
  - **Direct Mapping**: One approach maps Thomson Reuters data to Morningstar using TICKERS and CUSIPS. However, this method can be challenging due to the inherent complexities of these variables.
  - **Indirect Mapping via CRSP**: Alternatively, leveraging the existing mapping between CRSP and Thomson Reuters offers an indirect route to connect with Morningstar data, as Morningstar is already mapped with CRSP.

### Considerations for Usage

- **Relevance to Portfolio Holdings**: Adding the WFICN mapping is particularly useful if your research involves portfolio holdings. If holdings data is not a focus, this additional matching layer may not be necessary.

- **Code Usage Guidance**: In your scripts, if there is a line introducing WFICN for mapping purposes, it's crucial only for portfolio holdings analysis. If your work does not require this, you can skip this part and focus solely on the matching between CRSP and Morningstar Direct.

# Structuring Mapping Files for Extended Data at Monthly Frequency

## Overview

In the `MatchCRSPtoMsDandTR.R` script, we previously established a mapping between `crsp_fundno` (share class ID) and `crsp_portno` (portfolio ID) using CRSP's mapping file. Our research treats a fund as a portfolio, understanding share classes as varying investor contracts with differing fee structures, all representing portions of the same investment pool. CRSP provides crucial data on the duration for which share classes belong to specific portfolios.

## MonthlyFundIdMAP.R Script

- **Purpose**: The `MonthlyFundIdMAP.R` script utilizes the `ALLMAP` file, an output from the `MatchCRSPtoMsDandTR.R` script. This file structures the mapping as `crsp_fundno | ticker | ncusips | crsp_portno | FundId | wficn`, incorporating the `begdt` and `enddt` columns. These columns signify the start and end dates of a share class's association with a portfolio and a fund unit.

- **Transforming Data Structure**: The script is designed to convert these starting and ending dates into actual dates when the mapping is valid. This transformation is vital for structuring the data as a panel, allowing for efficient tracking of historical information every month. By transforming the data into this format, merging additional information later from various sources like CRSP, Morningstar, or Thomson Reuters becomes more straightforward.

## Outcome and Applications

- **MonthlyPortnoMAP File**: The outcome of the `MonthlyFundIdMAP.R` script is the `MonthlyPortnoMAP` database. This structured dataset becomes a fundamental tracking tool for US mutual funds research, enabling seamless integration of various data types, such as returns, portfolio holdings, transactions, fees, and other fund-level measures.

- **Versatility**: The `MonthlyPortnoMAP` file is versatile and can be used across different research processes, whether analyzing portfolio transactions, fees, returns, or other metrics. Its structure allows easy merging with data from CRSP, Morningstar, or Thomson Reuters and facilitates information connection across these sources.

The `MonthlyFundIdMAP.R` script dramatically simplifies building a comprehensive and multifaceted database for US mutual funds research by structuring the data into a user-friendly and easily navigable format.




