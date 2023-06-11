# PROVABLY RANDOM RAFFLE CONTRACTS

## About

This code is to create a provably random smart contract lottery

## What we want it to do...

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After x period of time, the lottery will automatically draw a winner (keeper?)
   1. This will be done programmatically
3. Using Chainlink VRF & Chainlink Automation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger (keeper?)

## Git shortcuts

- ga .
- gc '~'
- gs
- gp

## Tests!

1. Write some deploy tests
2. Write tests
   1. Work on a local chain
   2. Forked Testnet
   3. Forked Mainnet

All tests integrated with our deploy script
