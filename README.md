# student_DA — Mata Function for Student-Proposing Deferred Acceptance Algorithm

This repository contains a Mata implementation of the **student-proposing Deferred Acceptance (DA) algorithm**, used for matching students to schools (or programs). The algorithm accommodates **priority structures** and supports both **Single Tie-Breaking (STB)** and **Multiple Tie-Breaking (MTB)** lottery rules.

The code is useful for implementing school assignment mechanisms in empirical education research or policy simulations.

---

## 📌 Function Overview

The function `student_DA()` runs the student-proposing version of the Deferred Acceptance algorithm. It simulates rounds of proposals where students apply to their most preferred program not yet rejected, and schools evaluate applicants based on priorities and lottery numbers until a stable matching is reached.

The algorithm accounts for:
- **Binary priorities** (e.g., based on siblings, catchment, etc.)
- **Lottery tie-breaking**, either:
  - **STB**: same lottery number across all applications
  - **MTB**: distinct lottery number per student-program pair
- **Capacities** at schools or programs

---

## 🧾 Input Requirements

All input vectors must be non-missing and of equal length. Each row in the dataset must represent one **student-program pair** (i.e., long format).

| Argument         | Description |
|------------------|-------------|
| `long_students`  | Student ID (numeric), repeated for each program applied to |
| `long_schools`   | Program/School ID (numeric) |
| `long_rank`      | Rank of the program in student’s preference list (lower = more preferred; 1 = most preferred) |
| `long_priorities`| Indicator: 1 if student has priority at this program, 0 otherwise |
| `long_lot_nums`  | Lottery number for tie-breaking. Can be the same across all rows for STB or differ by row for MTB (lower numbers win) |
| `long_capacities`| Capacity for each program (must be constant for a given school) |
| `condition_mask` | A binary vector (1/0) indicating which rows of the STATA dataset should be considered in the algorithm |
| `outvarname`     | Name of the new variable to store results in the Stata dataset |

---

## 📐 Data Format

Your dataset **must be in long format**, i.e., one row per student-program pair.

The **`rank`** variable must be in **increasing order**, meaning:
- `rank = 1` → most preferred program
- `rank = 2` → second choice
- and so on.

---

## 📤 Output

A new variable named by `outvarname` will be created in the Stata dataset, storing the assigned program ID for each student. Unmatched students will have missing values.

---

## 📦 Usage

```stata
// Example usage inside Stata
mata student_DA(st_data(., "id"), st_data(., "prog_num"), st_data(., "rank"), st_data(., "prior"), st_data(., "lottery_STB"), st_data(., "school_cap"), st_data(., "mask"), "placement_alg")

---

## 📬 Contact

If you need any help understanding or implementing the code, please feel free to reach out via the contact links on my personal webpage:  
👉 [www.albertoantonello.com](https://www.albertoantonello.com)
