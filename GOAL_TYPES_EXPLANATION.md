# Goal Types Explained - Complete Guide

## Overview

The Goals feature supports **2 goal types** and **2 target configurations**, creating **4 possible combinations**. Let me break down each one with examples.

---

## 🎯 Goal Types

### 1. Saving Goals 💰

**Purpose**: Track how much money you're **accumulating** (income) toward a specific target.

**How Progress is Calculated**:
- System **sums all INCOME transactions**
- Optionally filtered by account or category
- Shows how much you've saved so far

**Use Cases**:
- "Save $5,000 for vacation"
- "Save $10,000 for emergency fund"
- "Save for new car down payment"
- "Save $2,000 for home renovation"

**Example**:
```
Goal: "Vacation Fund"
Type: Saving Goal
Target: $3,000

Progress:
- Salary income: +$1,200 → Current: $1,200 (40%)
- Freelance income: +$800 → Current: $2,000 (67%)
- Bonus: +$1,000 → Current: $3,000 (100%) ✅ COMPLETED!
```

---

### 2. Spending Limit Goals 🛑

**Purpose**: Track how much money you're **spending** (expenses) to stay within a budget limit.

**How Progress is Calculated**:
- System **sums all EXPENSE transactions**
- Optionally filtered by account or category
- Shows how much you've spent so far

**Use Cases**:
- "Monthly food budget: $500"
- "Entertainment spending limit: $200/month"
- "Shopping budget: $300"
- "Transportation expenses: $150/month"

**Example**:
```
Goal: "Monthly Food Budget"
Type: Spending Limit
Target: $500

Progress:
- Grocery shopping: -$150 → Current: $150 (30%)
- Restaurant: -$100 → Current: $250 (50%)
- Fast food: -$200 → Current: $450 (90%)
- Coffee: -$60 → Current: $510 (102%) ⚠️ OVER LIMIT!
```

**Visual Indicator**:
- Green progress bar: Under limit (good)
- Red progress bar: Over limit (warning)

---

## 📊 Target Amount Configuration

### Goals WITH Target Amount 🎯

**What It Means**: The goal has a specific monetary target to reach.

**Features**:
- ✅ Automatic progress calculation
- ✅ Visual progress bar (0-100%)
- ✅ Current amount / Target amount display
- ✅ Remaining amount calculation
- ✅ **Automatic completion** when target is reached
- ✅ **Locked completion** (cannot be unchecked once target achieved)

**Example - Saving Goal with Target**:
```
Goal: "Save $5,000 for vacation"
Target: $5,000
Current: $3,200
Progress: 64%
Remaining: $1,800
Status: In Progress
```

**Example - Spending Limit with Target**:
```
Goal: "Monthly food budget"
Target: $500
Current: $450
Progress: 90%
Remaining: $50
Status: In Progress (90% used)
```

---

### Goals WITHOUT Target Amount 📝

**What It Means**: The goal is a simple reminder or habit tracker without a specific monetary target.

**Features**:
- ❌ No automatic progress calculation
- ❌ No progress bar
- ❌ No amount tracking
- ✅ Manual completion only
- ✅ Can be marked complete/incomplete anytime
- ✅ Useful for reminders or non-monetary goals

**Example - Saving Goal without Target**:
```
Goal: "Build emergency fund"
Target: None
Current: N/A
Progress: N/A
Status: Manual tracking only
```

**Example - Spending Limit without Target**:
```
Goal: "Reduce unnecessary spending"
Target: None
Current: N/A
Progress: N/A
Status: Manual tracking only
```

---

## 🔄 Complete Comparison Matrix

| Feature | Saving Goal<br/>WITH Target | Saving Goal<br/>WITHOUT Target | Spending Limit<br/>WITH Target | Spending Limit<br/>WITHOUT Target |
|---------|---------------------------|------------------------------|------------------------------|----------------------------------|
| **Tracks** | Income transactions | N/A | Expense transactions | N/A |
| **Progress Bar** | ✅ Yes (0-100%) | ❌ No | ✅ Yes (0-100%+) | ❌ No |
| **Amount Display** | ✅ Current/Target | ❌ No | ✅ Current/Target | ❌ No |
| **Auto Completion** | ✅ When target reached | ❌ No | ✅ When limit reached | ❌ No |
| **Manual Completion** | ✅ Before target | ✅ Always | ✅ Before limit | ✅ Always |
| **Can Uncheck** | ❌ If target achieved | ✅ Always | ❌ If limit reached | ✅ Always |
| **Use Case** | "Save $5K for vacation" | "Build emergency fund" | "Food budget $500" | "Reduce spending" |

---

## 📋 Real-World Examples

### Example 1: Saving Goal WITH Target ✅

**Scenario**: You want to save $5,000 for a vacation in 6 months.

**Setup**:
- Type: **Saving Goal**
- Title: "Europe Vacation 2024"
- Target Amount: **$5,000** ✅
- Deadline: June 1, 2024
- Account: Savings Account (optional)
- Category: None (all income)

**How It Works**:
1. Every time you add an **income** transaction, progress updates
2. Progress bar shows: 0% → 25% → 50% → 75% → 100%
3. When you reach $5,000: **Automatic completion** + Celebration dialog
4. Goal is **locked as completed** (cannot be unchecked)

**Visual**:
```
[████████████░░░░░░░░] 60%
$3,000 / $5,000
$2,000 remaining
```

---

### Example 2: Saving Goal WITHOUT Target 📝

**Scenario**: You want to remind yourself to build an emergency fund, but don't have a specific target yet.

**Setup**:
- Type: **Saving Goal**
- Title: "Build Emergency Fund"
- Target Amount: **None** ❌
- Deadline: None
- Account: None
- Category: None

**How It Works**:
1. No automatic progress tracking
2. No progress bar or amounts shown
3. You manually mark it complete when you feel you've achieved it
4. Can be unchecked and re-checked anytime

**Visual**:
```
Build Emergency Fund
[Saving Goal] [Completed ✓]
(No progress bar, no amounts)
```

---

### Example 3: Spending Limit WITH Target 🛑

**Scenario**: You want to limit your monthly food spending to $500.

**Setup**:
- Type: **Spending Limit**
- Title: "Monthly Food Budget"
- Target Amount: **$500** ✅
- Deadline: End of month
- Account: All accounts
- Category: Food (optional filter)

**How It Works**:
1. Every time you add a **food expense**, progress updates
2. Progress bar shows: 0% → 20% → 50% → 80% → 100%+
3. Green bar when under limit, **red bar when over limit**
4. When you reach $500: **Automatic completion** (limit reached)
5. Goal is **locked as completed** (cannot be unchecked)

**Visual**:
```
[████████████████████] 90%
$450 / $500
$50 remaining
⚠️ Approaching limit!
```

**If Over Limit**:
```
[██████████████████████] 102%
$510 / $500
⚠️ OVER LIMIT by $10
```

---

### Example 4: Spending Limit WITHOUT Target 📝

**Scenario**: You want to remind yourself to reduce unnecessary spending, but don't want a specific limit.

**Setup**:
- Type: **Spending Limit**
- Title: "Reduce Unnecessary Spending"
- Target Amount: **None** ❌
- Deadline: None
- Account: None
- Category: None

**How It Works**:
1. No automatic progress tracking
2. No progress bar or amounts shown
3. You manually mark it complete when you feel you've achieved it
4. Can be unchecked and re-checked anytime

**Visual**:
```
Reduce Unnecessary Spending
[Spending Limit] [In Progress]
(No progress bar, no amounts)
```

---

## 🎯 Key Differences Summary

### Saving Goals vs Spending Limit Goals

| Aspect | Saving Goals | Spending Limits |
|--------|-------------|----------------|
| **Tracks** | Income (money coming in) | Expenses (money going out) |
| **Goal** | Accumulate money | Limit spending |
| **Progress** | Higher is better | Lower is better |
| **Completion** | Reach target amount | Reach limit amount |
| **Over Target** | ✅ Good (achieved!) | ⚠️ Bad (exceeded budget) |
| **Visual** | Green progress bar | Green (under) / Red (over) |

### With Target vs Without Target

| Aspect | WITH Target | WITHOUT Target |
|--------|------------|---------------|
| **Progress Tracking** | ✅ Automatic | ❌ Manual only |
| **Progress Bar** | ✅ Yes | ❌ No |
| **Amount Display** | ✅ Yes | ❌ No |
| **Auto Completion** | ✅ Yes | ❌ No |
| **Completion Lock** | ✅ Yes (if target reached) | ❌ No |
| **Use Case** | Specific monetary goal | Reminder/habit tracker |

---

## 💡 When to Use Each Type

### Use **Saving Goal WITH Target** when:
- ✅ You have a specific amount to save
- ✅ You want to track progress automatically
- ✅ You want visual feedback (progress bar)
- ✅ Examples: "Save $5K for vacation", "Save $10K emergency fund"

### Use **Saving Goal WITHOUT Target** when:
- ✅ You want a simple reminder
- ✅ You don't have a specific target yet
- ✅ You want to track manually
- ✅ Examples: "Build emergency fund", "Start saving"

### Use **Spending Limit WITH Target** when:
- ✅ You have a specific budget limit
- ✅ You want to track spending automatically
- ✅ You want warnings when approaching/over limit
- ✅ Examples: "Food budget $500", "Entertainment $200/month"

### Use **Spending Limit WITHOUT Target** when:
- ✅ You want a general reminder to reduce spending
- ✅ You don't want a specific limit
- ✅ You want to track manually
- ✅ Examples: "Reduce unnecessary spending", "Cut back on expenses"

---

## 🔍 Visual Comparison

### Saving Goal WITH Target:
```
┌─────────────────────────────────┐
│ 🎯 Save $5,000 for Vacation    │
│ [Saving Goal] [In Progress]    │
│                                 │
│ [████████████░░░░░░░░] 60%     │
│ $3,000 / $5,000                │
│ $2,000 remaining               │
│                                 │
│ ☑️ (checkbox enabled)          │
└─────────────────────────────────┘
```

### Saving Goal WITHOUT Target:
```
┌─────────────────────────────────┐
│ 📝 Build Emergency Fund         │
│ [Saving Goal] [In Progress]     │
│                                 │
│ (No progress bar)               │
│ (No amounts shown)              │
│                                 │
│ ☑️ (checkbox enabled)          │
└─────────────────────────────────┘
```

### Spending Limit WITH Target:
```
┌─────────────────────────────────┐
│ 🛑 Monthly Food Budget          │
│ [Spending Limit] [In Progress] │
│                                 │
│ [████████████████████] 90%     │
│ $450 / $500                    │
│ $50 remaining                  │
│ ⚠️ Approaching limit!          │
│                                 │
│ ☑️ (checkbox enabled)          │
└─────────────────────────────────┘
```

### Spending Limit WITHOUT Target:
```
┌─────────────────────────────────┐
│ 📝 Reduce Unnecessary Spending  │
│ [Spending Limit] [In Progress]  │
│                                 │
│ (No progress bar)               │
│ (No amounts shown)              │
│                                 │
│ ☑️ (checkbox enabled)          │
└─────────────────────────────────┘
```

---

## ✅ Quick Decision Guide

**Want to track progress automatically?**
→ Use **WITH Target**

**Just want a reminder?**
→ Use **WITHOUT Target**

**Want to save money?**
→ Use **Saving Goal**

**Want to limit spending?**
→ Use **Spending Limit**

**Have a specific amount?**
→ Use **WITH Target**

**Don't have a specific amount?**
→ Use **WITHOUT Target**

---

## 🎓 Summary

1. **Saving Goals** = Track income (money coming in) toward a target
2. **Spending Limits** = Track expenses (money going out) to stay within a budget
3. **WITH Target** = Automatic progress tracking, visual feedback, auto-completion
4. **WITHOUT Target** = Manual tracking only, simple reminders, flexible completion

**The combination gives you 4 powerful ways to track your financial goals!** 🎯

