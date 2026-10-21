# Field tables used by the client

Extracted mechanically from the web client's generated protobuf module (1,706 message classes) by
driving each generated `encode` with a recording writer — see `tools/extract_fields.mjs`. Tags are
protobuf field numbers; `wire` 0 = varint, 2 = length-delimited (string/bytes/message).

### base.RequestContext

| field | tag | type |
|-------|-----|------|
| `requestId` | 1 | bytes |
| `authenticationToken` | 4 | message |
| `signedChallenge` | 5 | message |
| `app` | 8 | message |
| `locale` | 9 | message |
| `accountProfileInfo` | 10 | message |
| `platform` | 11 | message |
| `networkInterface` | 13 | message |
| `custom` | 31 | message |

### base.Authentication

| field | tag | type |
|-------|-----|------|
| `devicePublicKey` | 1 | bytes |
| `anonymous` | 2 | message |
| `plain` | 3 | message |
| `signedChallenge` | 4 | message |
| `privilegedPlain` | 5 | message |
| `refreshToken` | 11 | string |
| `ssoDomain` | 21 | message |

### base.AuthenticationPlain

| field | tag | type |
|-------|-----|------|
| `username` | 1 | string |
| `password` | 2 | message |

### base.AuthenticationToken

| field | tag | type |
|-------|-----|------|
| `issueDate` | 1 | message |
| `expireDate` | 2 | message |
| `bearer` | 3 | bytes |
| `ssoToken` | 21 | string |

### base.Password

| field | tag | type |
|-------|-----|------|
| `encoded` | 1 | bytes |

### base.AppInfo

| field | tag | type |
|-------|-----|------|
| `version` | 1 | message |
| `installationSource` | 2 | string |
| `bundleId` | 3 | string |

### base.Platform

| field | tag | type |
|-------|-----|------|
| `type` | 1 | int32 |
| `os` | 2 | int32 |
| `version` | 3 | message |
| `releaseVersion` | 4 | string |
| `securityPatch` | 5 | string |
| `sdkVersion` | 6 | int32 |
| `localizedDescription` | 15 | string |

### base.Locale

| field | tag | type |
|-------|-----|------|
| `identifier` | 1 | string |
| `localizedDescription` | 15 | string |

### base.Device

| field | tag | type |
|-------|-----|------|
| `id` | 1 | bytes |
| `appInfo` | 2 | message |
| `platform` | 3 | message |
| `model` | 4 | message |
| `name` | 5 | string |
| `flags` | 6 | message |
| `locale` | 7 | message |
| `status` | 8 | int32 |
| `ip` | 9 | message |
| `location` | 10 | message |
| `registrationDate` | 11 | message |
| `lastLoginDate` | 12 | message |
| `lastConnectionInfo` | 13 | message |
| `advertisementInfo` | 14 | message |
| `localizedDescription` | 15 | string |

### base.RequestAccountProfileInfo

| field | tag | type |
|-------|-----|------|
| `profileId` | 1 | string |
| `profileType` | 2 | int32 |
| `accountNumber` | 3 | message |
| `accountType` | 4 | int32 |

### base.Amount

| field | tag | type |
|-------|-----|------|
| `value` | 1 | message |
| `currency` | 2 | message |
| `localizedDescription` | 15 | string |

### base.DecimalValue

| field | tag | type |
|-------|-----|------|
| `rawValue` | 1 | string |
| `isNan` | 2 | bool |
| `localizedDescription` | 15 | string |

### base.Currency

| field | tag | type |
|-------|-----|------|
| `isoCode` | 1 | string |
| `localizedDescription` | 15 | string |

### services.SessionKeyExchangeRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `deviceId` | 2 | bytes |
| `publicKey` | 3 | bytes |
| `cipherMethod` | 4 | int32 |

### services.SessionKeyExchangeResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `keyId` | 2 | string |
| `publicKey` | 3 | bytes |

### services.SessionLoginRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `authentication` | 3 | message |
| `device` | 4 | message |
| `lastUsedProfileId` | 5 | string |

### services.SessionLoginResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `authenticationToken` | 2 | message |
| `refreshToken` | 3 | string |
| `navigationUri` | 5 | message |
| `remoteConfig` | 7 | message |

### services.UserOTPVerifyRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `otpRequest` | 2 | message |
| `oneTimePin` | 3 | message |
| `lastUsedProfileId` | 4 | string |

### services.UserOTPVerifyResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `navigationUri` | 2 | message |
| `encryptedPhoneNumber` | 4 | string |
| `authenticationToken` | 5 | message |
| `featureFlags` | 7 | message |

### services.UserGetProfileRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |

### services.UserGetProfileResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `user` | 2 | message |
| `person` | 3 | message |
| `profileAttributes` | 4 | message |
| `encryptedPhoneNumber` | 5 | string |

### services.AccountListAllRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `page` | 2 | message |
| `accountQuery` | 3 | message |

### services.AccountListAllResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `nextPage` | 2 | message |
| `accounts` | 3 | message |
| `totalActualBalance` | 6 | message |
| `totalBalances` | 7 | message |

### services.AccountProfileListRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `query` | 3 | message |

### services.AccountProfileListResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `profiles` | 3 | message |
| `initiateOptions` | 4 | message |

### services.TransactionListAllRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `page` | 2 | message |
| `transactionQuery` | 3 | message |
| `essentialData` | 4 | message |

### services.TransactionListAllResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `nextPage` | 2 | message |
| `transactions` | 3 | message |
| `previousPage` | 12 | message |

### services.CardListAllRequest

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `page` | 2 | message |
| `cardQuery` | 3 | message |

### services.CardListAllResponse

| field | tag | type |
|-------|-----|------|
| `context` | 1 | message |
| `nextPage` | 2 | message |
| `cards` | 3 | message |

### bluebank.Account

| field | tag | type |
|-------|-----|------|
| `id` | 1 | message |
| `type` | 3 | message |
| `status` | 4 | message |
| `representations` | 5 | message |
| `amounts` | 6 | message |
| `date` | 7 | message |
| `capabilities` | 8 | message |
| `info` | 9 | message |
| `ownerName` | 10 | message |
| `additionalDescription` | 13 | string |
| `userDescription` | 14 | string |
| `localizedDescription` | 15 | string |
| `state` | 16 | message |

### bluebank.AccountIdentifier

| field | tag | type |
|-------|-----|------|
| `accountNumber` | 1 | message |
| `pan` | 2 | message |
| `iban` | 3 | message |
| `bank` | 14 | message |
| `localizedDescription` | 15 | string |

### bluebank.AccountAmounts

| field | tag | type |
|-------|-----|------|
| `actualBalance` | 1 | message |
| `availableBalance` | 2 | message |
| `minimumBalance` | 3 | message |
| `holdingBalance` | 4 | message |

### bluebank.AccountProfile

| field | tag | type |
|-------|-----|------|
| `id` | 1 | string |
| `accounts` | 2 | message |
| `name` | 3 | string |
| `profileImage` | 4 | message |
| `type` | 5 | message |
| `status` | 6 | message |
| `user` | 7 | message |
| `person` | 8 | message |
| `profileAttributes` | 9 | message |
| `encryptedPhoneNumber` | 10 | string |
| `personalBusinessAttributes` | 20 | message |

### bluebank.Transaction

| field | tag | type |
|-------|-----|------|
| `id` | 1 | string |
| `accountId` | 2 | message |
| `category` | 3 | message |
| `amounts` | 4 | message |
| `dates` | 5 | message |
| `type` | 6 | message |
| `status` | 7 | message |
| `counterparty` | 10 | message |
| `additionalInfo` | 11 | message |
| `trackingInfo` | 12 | message |
| `memo` | 13 | string |
| `additionalDescription` | 14 | string |
| `localizedDescription` | 15 | string |
| `merchantCategory` | 16 | message |
| `receipt` | 17 | message |
| `merchantCategoryUneditable` | 19 | bool |
| `systemDescription` | 20 | string |
| `linkedTransactionIds` | 21 | string |
| `counterpartyActionable` | 22 | bool |
| `sourceAccountType` | 23 | int32 |
| `transactionFlags` | 24 | message |
| `excludedInAggregation` | 25 | bool |
| `message` | 26 | message |

### bluebank.TransactionAmounts

| field | tag | type |
|-------|-----|------|
| `amount` | 1 | message |
| `postedActualBalance` | 2 | message |
| `postedAvailableBalance` | 3 | message |
| `originalAmount` | 8 | message |
| `discountPercent` | 9 | message |

### bluebank.TransactionCategory

| field | tag | type |
|-------|-----|------|
| `icon` | 1 | message |
| `title` | 2 | string |

### bluebank.Card

| field | tag | type |
|-------|-----|------|
| `id` | 1 | string |
| `number` | 2 | message |
| `holderName` | 3 | message |
| `linkedAccount` | 4 | message |
| `type` | 5 | message |
| `status` | 6 | message |
| `shippingStatus` | 7 | message |
| `date` | 8 | message |
| `cvv2` | 9 | message |
| `reorderStatus` | 11 | int32 |
| `hint` | 12 | message |
| `design` | 13 | message |
| `cardNotPresentDisabled` | 14 | bool |
| `cardPresentDisabled` | 16 | bool |
