LiquidityPool.sol - Reviewed, nothing big. Help?
LiquidityFarmiing.sol - 
```  LiquidityFarming.sol::135 - if (amount > 0) {
  LiquidityFarming.sol::321 - if (totalSharesStaked[_baseToken] > 0) {
 LiquidityFarming.sol::236 - for (index = 0; index < nftsStakedLength; ++index) {
 ```
 
 Liquidity Provider -
```  LiquidityProvider.sol::182 - if (supply > 0) {
  LiquidityProvider.sol::239 - require(_amount > 0, "ERR__AMOUNT_IS_0");
  LiquidityProvider.sol::283 - require(_amount > 0, "ERR__AMOUNT_IS_0");
  LiquidityProvider.sol::410 - require(lpFeeAccumulated > 0, "ERR__NO_REWARDS_TO_CLAIM");
  ```
  
