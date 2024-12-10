# Simple Larry Uni V3 Simulator

This simple script simulate the following scenario in [sim.s.sol](script/sim.s.sol): 

- The total supply of the meme token is 1e9 (using 18 decimals, so in wei, it is 1e9 ether)
- We have raised 3ETH, and commit the 30% of the supply to the contributors
- We take 0.2ETH fee, so only 2.8 ETH will be added as liquidity 
- The remaining 70% supply of the token will be added as liquidity 

Liquidity Range: 

- A extremely concentrated range with only ETH => when all the 30% supply of the token dumpped into the pool, we have less than 3% price drop 
- A wide range with only Token => let the token have space to go to the moon. 



# Run 


simulate buy after listed on Uniswap V3: 


```shell 
forge script -vvvv --tc Sim  --rpc-url https://rpc.ankr.com/base  --sig 'run(bool)' script/sim.s.sol  true
```

Result: 

```
  after bought 5 eth, we have total bought 299923685.448552461811256132 token, the price of token denominated in eth is 0.000000028876837837
  after bought 10 eth, we have total bought 419925206.031713271791970555 token, the price of token denominated in eth is 0.000000058923327672
  after bought 15 eth, we have total bought 484548996.708181883785615027 token, the price of token denominated in eth is 0.000000099572239302
  after bought 20 eth, we have total bought 524941563.309854610091354492 token, the price of token denominated in eth is 0.000000150823572728
  after bought 25 eth, we have total bought 552579778.200833222764508573 token, the price of token denominated in eth is 0.000000212677327948
  after bought 30 eth, we have total bought 572680908.325967120084756366 token, the price of token denominated in eth is 0.000000285133504963
  after bought 35 eth, we have total bought 587958110.901971047145130326 token, the price of token denominated in eth is 0.000000368192103774
  after bought 40 eth, we have total bought 599961835.442998609013508821 token, the price of token denominated in eth is 0.000000461853124379
  after bought 45 eth, we have total bought 609642391.939146590756887255 token, the price of token denominated in eth is 0.000000566116566779
  after bought 50 eth, we have total bought 617614704.424143242355992418 token, the price of token denominated in eth is 0.000000680982430974
  after bought 55 eth, we have total bought 624294271.710005978999647203 token, the price of token denominated in eth is 0.000000806450716964
  after bought 60 eth, we have total bought 629971948.515317734560980342 token, the price of token denominated in eth is 0.00000094252142475
  after bought 65 eth, we have total bought 634857424.161982357347395675 token, the price of token denominated in eth is 0.00000108919455433
  after bought 70 eth, we have total bought 639105688.527637470202749033 token, the price of token denominated in eth is 0.000001246470105705
  after bought 75 eth, we have total bought 642833776.164850554553882487 token, the price of token denominated in eth is 0.000001414348078875
  after bought 80 eth, we have total bought 646131714.57757650386953298 token, the price of token denominated in eth is 0.00000159282847384
  after bought 85 eth, we have total bought 649069889.541350821289709417 token, the price of token denominated in eth is 0.0000017819112906
  after bought 90 eth, we have total bought 651704124.704649637568395046 token, the price of token denominated in eth is 0.000001981596529156
  after bought 95 eth, we have total bought 654079262.335252502994592802 token, the price of token denominated in eth is 0.000002191884189506
  after bought 100 eth, we have total bought 656231737.009717130955185573 token, the price of token denominated in eth is 0.000002412774271651
```


simulate sell after listed on Uniswap V3 


```shell
forge script -vvvv --tc Sim  --rpc-url https://rpc.ankr.com/base  --sig 'run(bool)' script/sim.s.sol  false
```


Result: 

```
  let's simulate the dump...
  after sold 50000000 token, the price of token denominated in eth is 0.000000009215996736
  after sold 100000000 token, the price of token denominated in eth is 0.000000009186141568
  after sold 150000000 token, the price of token denominated in eth is 0.00000000915643124
  after sold 200000000 token, the price of token denominated in eth is 0.000000009126864814
  after sold 250000000 token, the price of token denominated in eth is 0.000000009097441365
  after sold 300000000 token, the price of token denominated in eth is 0.00000000906815997
```