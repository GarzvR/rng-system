# RNG System

A professional, minimalist RNG (Random Number Generator) system for Roblox.

## Features
- **Data Persistence**: Automatic save/load using DataStoreService.
- **Luck & Pity**: Permanent luck multiplier that increases based on total spins.
- **Monetization**: 5x Luck Boost (stackable duration) via Developer Products.
- **Clean UI**: Minimalist, transparent "Glassmorphism" UI design.
- **Inventory & Equip**: Dynamic inventory listing with particle-based auras.

## Installation
1. Place `RNGServer.lua` inside `ServerScriptService`.
2. Create a `RemoteEvent` folder in `ReplicatedStorage` named `RNGEvents`.
3. Create the following `RemoteEvent`s inside `RNGEvents`:
   - `RollEvent`
   - `EquipEvent`
   - `UpdateDataEvent`
   - `BoostUpdateEvent`
4. Setup your `RNGGui` (ScreenGui) in `StarterGui` and place `RNGClient.lua` inside it as a `LocalScript`.

## Configuration
Update the `LUCK_BOOST_PRODUCT_ID` at the top of both scripts with your own Developer Product ID from the Roblox Creator Dashboard.
