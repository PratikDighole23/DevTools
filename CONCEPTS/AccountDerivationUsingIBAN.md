// ...existing code...
# Alias and IBAN configuration for account derivation

Purpose
- Describe how to derive an account identifier from an IBAN using the alias/IBAN configuration and alias-derivation APIs.

Prerequisites
- IBAN must be present in the incoming payload.
- Set environment flag `IBAN_CONFIG_SCHM=true` to use `ibanConfig` from `PymtBankParams`. Otherwise the reference configuration will be used.

High-level steps
1. Enable alias requests in payment parameters:
   - Set `aliasReq = true` in `PymtSchmParams` and `PymtSrvcParam`.
2. Add alias input and match type in `PymtSrvcParam`.
3. Ensure `ibanConfig` is present in `PymtBankParams` (example below).
4. Call AliasResolution / aliasDerivation APIs with the IBAN.
5. Populate IBAN reference data in Redis (ND::IBANS, ND::IBANP, ND::IBANR).
6. Derived account number is returned per the IBAN rules.

Example: ibanConfig (PymtBankParams)
```json
{
  "constructIban": false,
  "deconstructIban": true,
  "ibanSDirectoryName": "IBANS",
  "ibanPDirectoryName": "IBANP",
  "ibanEDirectoryName": "IBANE",
  "ibanRDirectoryName": "IBANR",
  "realAccountIdLength": 1,
  "deconstructIbanAliasTypes": ["RLIBAN"],
  "ibanFDirectoryName": "IBANF",
  "ibanIDirectoryName": "IBANI",
  "ibanHDirectoryName": "IBANH",
  "ibanDirectoryType": "IBD"
}
```

AliasResolution API (example)
- Endpoint: `api/AliasPatterns/AliasResolution`
- Request body example:
```json
{
  "aliasCode": "SCRT1",
  "aliasInputPriority": [
    {
      "path": "iban",
      "priority": 1,
      "aliasMatchType": ["RLIBAN"]
    }
  ],
  "ibanConfig": {
    "constructIban": false,
    "deconstructIban": true,
    "ibanSDirectoryName": "IBANS",
    "ibanPDirectoryName": "IBANP",
    "ibanEDirectoryName": "IBANE",
    "ibanRDirectoryName": "IBANR",
    "realAccountIdLength": 1,
    "deconstructIbanAliasTypes": ["RLIBAN"],
    "ibanFDirectoryName": "IBANF",
    "ibanIDirectoryName": "IBANI",
    "ibanHDirectoryName": "IBANH",
    "ibanDirectoryType": "IBD",
    "deconstructIBAN": true
  },
  "initgModule": "DEFAULT",
  "serviceId": "NCP-I",
  "data": {
    "partyName": "BENENAME",
    "iban": "DE88390500007204757420",
    "acctPrxyId": "<long-acctPrxyId>",
    "partyType": "CRP"
  }
}
```

aliasDerivation API (example)
- Endpoint: `api/AliasPatterns/aliasDerivation`
- Request body example:
```json
{
  "aliasPaysysId": "SCRT1",
  "aliasData": [
    {
      "input": "DE94390500001690940722",
      "priority": 1,
      "aliasMatchType": ["RLIBAN"]
    }
  ],
  "isFunctionCall": true
}
```

Redis data required
- Populate the relevant ND::IBANS, ND::IBANP, ND::IBANR keys for the country / bank in Redis. Example commands for IBAN `DE88390500007204757420`:

hset ND::IBANR "de" "{\"COUNTRY CODE\":\"DE\",\"BBAN REGEX\":\"(?=.{18}$)^\\\\d{8}\\\\d{10}$\",\"IBAN REGEX\":\"(?=.{22}$)^DE\\\\d{2}\\\\d{8}\\\\d{10}$\",\"QR IBAN REGEX\":\"(?=.{22}$)^DE\\\\d{2}\\\\d{8}\\\\d{10}$\",\"VA IBAN REGEX\":\"(?=.{22}$)^DE\\\\d{2}\\\\d{8}\\\\d{10}$\",\"ndSourceFile\":\"44A65AE5FF3BF706E063857B490AF8F2\"}

hset ND::IBANP "de::39050000" "{\"MODIFICATION FLAG\":\"A\",\"RECORD KEY\":\"IB00000008P1\",\"INSTITUTION NAME\":\"Sparkasse Aachen\",\"COUNTRY NAME\":\"GERMANY\",\"ISO COUNTRY CODE\":\"DE\",\"IBAN ISO COUNTRY CODE\":\"DE\",\"IBAN BIC\":\"AACSDE33XXX\",\"ROUTING BIC\":\"AACSDE33XXX\",\"IBAN NATIONAL ID\":\"39050000\",\"ndSourceFile\":\"44A4B0FCB1C31387E063857B490A00C5\"}"

hset ND::IBANS "de" "{\"MODIFICATION FLAG\":\"A\",\"RECORD KEY\":\"IS000000000F\",\"IBAN COUNTRY CODE\":\"DE\",\"IBAN COUNTRY CODE POSITION\":\"1\",\"IBAN COUNTRY CODE LENGTH\":\"2\",\"IBAN CHECK DIGITS POSITION\":\"3\",\"IBAN CHECK DIGITS LENGTH\":\"2\",\"BANK IDENTIFIER POSITION\":\"5\",\"BANK IDENTIFIER LENGTH\":\"8\",\"BRANCH IDENTIFIER LENGTH\":\"0\",\"IBAN NATIONAL ID LENGTH\":\"8\",\"ACCOUNT NUMBER POSITION\":\"13\",\"ACCOUNT NUMBER LENGTH\":\"10\",\"IBAN TOTAL LENGTH\":\"22\",\"SEPA\":\"Y\",\"MANDATORY COMMENCE DATE\":\"20140201\",\"ISO13616\":\"Y\",\"_ndSourceFile\":\"401749DC3F82F69EE063857B490AF0BA\"}"
```

Expected outcome
- With correct configuration and Redis data, the system deconstructs the IBAN and derives the real account identifier (example derived account: 7204757420).

Notes and troubleshooting
- Ensure `deconstructIban`/`deconstructIBAN` and `deconstructIbanAliasTypes` include the alias type used (e.g., `RLIBAN`).
- Verify Redis keys and JSON payloads for correct country codes and formats.
- Validate IBAN regex patterns in `ND::IBANR` to match the payload.


// ...existing code...