## TL;DR

This proposal unpauses the Mento Token, enabling normal token transfers for all users. Initially launched as a non-transferable governance token, the MENTO token was designed with a future option to become transferable contingent upon the protocol’s maturity, as well as community and market readiness. Given Mento's significant progress, product traction, and strategic focus on stablecoin-based onchain FX markets, enabling token transferability is now timely and beneficial for the protocol's continued growth and decentralization.

### Motivation

Activating MENTO token transferability is expected to:

- **enhance liquidity and accessibility**, enabling a wider and more diverse group of stakeholders to actively participate in Mento governance;
- **facilitate deeper decentralization** by incentivizing and empowering new contributors, further distributing governance influence across the community;
- **strengthen the protocol's resilience and community ownership** by further decentralizing token holdings;
- **align token utility with current market expectations**, working towards tangible economic incentives that drive innovation, active participation, and strategic collaborations within the broader decentralized finance ecosystem.

### Rationale

Mento has reached significant milestones demonstrating the community's readiness for token transferability:

- **Mento decentralized local currency stablecoins** are among the growing stablecoins in the industry with 15 local stablecoins live, that include all G7s and key African, LatAm, and South East Asian currencies
- **The Mento Asset Exchange**, integrated into leading solutions like Squid Router or Opera MiniPay, processed over 550 million transactions in 2024
- **Mento has over 8m users** with around 400k daily active users and strategic partnerships with major global organizations, including Deutsche Telekom, Opera, Chainlink, RedStone, Valora, Fonbnk, Yellow Card, and many more
- **MENTO is about to unlock the next stage of growth** with onchain FX trading

### Transaction Details

This proposal consists of one transaction:

**TX#0:** call the `unpause()` function on the MentoToken contract

- Target: MentoToken contract
- Function: `unpause()`
- Parameters: None

**Relevant Addresses for verification**

- MentoToken
  - [_0x7FF62f59e3e89EA34163EA1458EEBCc81177Cfb6_](https://celoscan.io/address/0x7FF62f59e3e89EA34163EA1458EEBCc81177Cfb6)

### Legal disclaimer

Mento is a decentralized and community-governed platform. This is not an offer to sell or the solicitation of an offer to purchase any MENTO tokens, and is not an offering, advertisement, solicitation, confirmation, statement or any financial promotion that can be construed as an invitation or inducement to engage in any investment activity or similar. You should not rely on the content here for advice of any kind, including legal, investment, financial, tax, or other professional advice, and such content is not a substitute for advice from a qualified professional.

The token utility explorations should be seen merely as preliminary conceptual ideas, which are likely to be subject to substantial change. Before any implementation, extensive analysis is required to get a clear picture on aspects such as legal/regulatory risks, technical feasibility, resource availability, product roadmap etc.

Any documentation or statements are provided for informational purposes only and do not constitute financial advice, a prospectus, a key information document, or any other similar document. No prospectus, key information document, or similar document will be provided at any time. There is no guarantee of the completeness and accuracy of the documentation statements provided. All numbers and forward-looking statements mentioned here in the forum, as well as any accompanying documentation and/or statements reflect mere estimations/indications. They are not guaranteed and may change substantially.
