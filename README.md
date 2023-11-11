# Cityhall Script for FiveM

🚧 **BETA Version Notice** 🚧

This script is in its BETA phase. We've conducted thorough testing, but please be aware of potential unforeseen issues or bugs.

## 🌟 Features

### Namechange Office
Empower players to change their in-game names seamlessly.

### Social Money System
A unique system providing social money to eligible players, enhancing the roleplay experience.

### Playtime Tracker
Keep track of each player's total playtime on the server.

### Stats Function
A comprehensive menu for players to view various statistics, including playtime.

### Leaderboard Function
Showcase top players in categories like "Most Playtime" and "Richest Player."

### Playtime Rewards
Incentivize your players with rewards for their playtime, including weapons, money, or items.

### Registry Office
A feature for players to get married or divorced within the game, adding depth to roleplay.

## 🛠 Upcoming Features

- **Vehicle Category**: Enhanced tracking and management of vehicles.

## 🤝 Support, Feedback & Collaboration

Encountering issues or bugs? Have suggestions for improvements? Reach out to me on Discord: byK3.

I'm always open to ideas, wishes, and contributions to the project. If you're interested in collaborating, please contact me via Discord.

## 📚 Exports

```lua
exports('GetPlayerKills', GetPlayerKills)
exports('GetPlayerDeaths', GetPlayerDeaths)
exports('GetPlayerKDRatio', GetPlayerKDRatio)
exports('GetPlayerPlaytime', GetPlayerPlaytime)
```

📖 Usage Example
```lua
local kills = exports.k3_cityhall:GetPlayerKills(playerIdentifier)
local deaths = exports.k3_cityhall:GetPlayerDeaths(playerIdentifier)
local kd_ratio = exports.k3_cityhall:GetPlayerKDRatio(playerIdentifier)
local playtime = exports.k3_cityhall:GetPlayerPlaytime(playerIdentifier)

print('Kills:', kills, 'Deaths:', deaths, 'KD Ratio:', kd_ratio, 'Playtime:', playtime)
````
Stay tuned for more updates and enhancements as we continue to develop and refine the Cityhall experience for FiveM!



Ensure that you replace placeholders like `playerIdentifier` with actual variables or identifiers used in your script.
