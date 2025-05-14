# 🧠 DeFiInsight Platform

**Advanced DeFi Monitoring & Incentivization with Commitment Locks**

DeFiInsight is a Clarity-based decentralized finance (DeFi) smart contract for Stacks, designed to monitor, incentivize, and stabilize user commitments via STX staking. With features like lock-period rewards, yield multipliers, and tier-based access, the platform promotes long-term participation while offering dynamic configuration and robust safety mechanisms.

---

## 🚀 Features

* **STX Commitment with Yield**: Stake STX with optional lock periods to earn INSIGHT-TOKEN rewards.
* **Tiered Membership System**: Users are assigned membership tiers based on commitment amounts, unlocking yield boosts and capabilities.
* **Time-Locked Withdrawals**: Enforced cooldowns and lock durations ensure system stability.
* **Customizable Network Configs**: Add and manage DeFi-compatible external networks.
* **Reward Booster Mechanics**: Yield is influenced by both lock duration and membership tier.
* **Safety Controls**: Includes admin-controlled crisis mode and platform suspension.

---

## 📦 Smart Contract Components

### Tokens

* `INSIGHT-TOKEN`: Platform-native fungible token used as yield rewards.

### Data Structures

* **ParticipantMetrics**: Tracks user-specific participation and tier.
* **CommitmentDetails**: Records staking history, lock duration, and rewards.
* **MembershipTiers**: Defines reward boosts and feature access for each tier.
* **CompatibleNetworks**: Stores configurations for supported DeFi networks.

### Variables

* `system-suspended`: Global kill switch to pause operations.
* `crisis-mode`: Additional emergency flag for external integrations.
* `default-yield`: Standard APY percentage baseline.
* `cooldown-duration`: Blocks to wait before unlocking funds.

---

## 🛠️ Admin Functions

| Function                    | Description                                             |
| --------------------------- | ------------------------------------------------------- |
| `setup-platform`            | Initializes tiers and networks.                         |
| `adjust-system-status`      | Enables/disables platform activity.                     |
| `adjust-crisis-mode`        | Enables/disables crisis mode.                           |
| `modify-network-parameters` | Edits volatility and incentive parameters for networks. |

---

## 💰 User Functions

| Function                             | Description                                     |
| ------------------------------------ | ----------------------------------------------- |
| `commit-stx (quantity, lock-period)` | Stake STX with optional lock-in duration.       |
| `request-exit (quantity)`            | Initiate withdrawal process after lock expires. |
| `complete-exit (quantity)`           | Withdraw funds after cooldown period.           |
| `collect-rewards`                    | Claim accumulated yield in `INSIGHT-TOKEN`.     |

---

## 🧮 Reward Logic

* **Base Yield**: Default is `5% APY`, scaled by blocks.
* **Tier Booster**:

  * Tier 1: 1.0x
  * Tier 2: 1.5x
  * Tier 3: 2.0x
* **Lock Period Bonus**:

  * No Lock: 1.0x
  * 1 Month+: 1.25x
  * 2 Months+: 1.5x

```text
Total Yield = (Base Yield) × (Tier Multiplier) × (Lock Bonus)
```

---

## 🔐 Lock & Exit Flow

1. `commit-stx`: Stake and lock STX.
2. After lock expires, call `request-exit`.
3. Wait cooldown (`~24h`), then `complete-exit` to withdraw.

---

## 🧑‍💻 Development

### Requirements

* Stacks CLI
* Clarity VM / Clarinet

### Deploying Locally

```bash
clarinet check       # Validate syntax
clarinet test        # Run unit tests
clarinet deploy      # Deploy contract to localnet
```

---

## ⚠️ Error Codes

| Code   | Meaning                        |
| ------ | ------------------------------ |
| `4001` | Permission denied (admin-only) |
| `4002` | Chain/network unsupported      |
| `4003` | Invalid commitment quantity    |
| `4004` | Insufficient STX committed     |
| `4005` | Waiting/lock period not met    |
| `4006` | No active participation        |
| `4007` | Threshold not met              |
| `4008` | System is suspended            |

---

## 📄 License

MIT License

---

## 🙋 FAQ

**Q: How are rewards calculated?**
A: Rewards are calculated per block and depend on your STX amount, tier level, and lock duration.

**Q: What happens during a suspension?**
A: All user operations are halted until resumed by an admin.

**Q: Can I participate without locking funds?**
A: Yes, but your yield will be lower due to the absence of a lock bonus.

---

## ✨ Contribution

Feel free to open issues or PRs for improvements. Collaboration is welcome!
