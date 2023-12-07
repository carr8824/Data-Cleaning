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

- **Mapping File Format**: This process's final output file is structured as `Morningstar FundId | TICKER | CUSIP`. This format represents the culmination of the mapping information derived from Morningstar.




