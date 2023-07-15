# Grant Funding Distribution Algorithm （Progressive Tax V2）

This algorithm is an attempt to solve the inequality problem in quadratic voting and quadratic funding systems. It aims to reduce the gap between the most matched project and the least matched project.

The idea is to set a maximum spread between the most funded and the least funded, and dynamically adjust funding results - the algorithm runs after every vote. At the same time, the algorithm preserves the structure of quadratic voting and quadratic funding.

There is simple implementations of this algorithm without need of big storage. Therefore, we implement this algorithm on-chain.

We save the following information in the grant contract (some are Dora grant specific):

The algorithm independently calculates matching results of every category (track) from every round. Therefore, the following data fields will be indexed by Round + Category.

- Number of projects `N`
- Each project's votes `V_n`
- Largest number of votes received by a single project `V_max`
- Smallest number of votes received by a single project `V_min`
- Total votes `V_sum`

> Each time `vote()` is called, all above data will be updated

The algorithm also requires to store `R` in the contract, which is the largest funding gap allowed between the top and bottom projects, i.e.

```js
matching_max / matching_min <= R
```

The algorithm runs as follows: all projects' votes are normalized to `V_avg` based on `s`. The process guarantees that total votes will not change, therefore, each project's matching fund can be calculated individually, independent from other projects' votes.

Then we have the following equations:

```js
V_avg = V_sum / N

// V_max >= V_avg >= V_min
V_max_final = (V_max - V_avg) * s + V_avg
V_min_final = (V_min - V_avg) * s + V_avg

V_max_final / V_min_final = R
```

We can calculate `s` from the above equations:

```js
// (V_max - V_avg) * s + V_avg = R * ((V_min - V_avg) * s + V_avg)

// (V_max - V_avg + (V_avg - V_min) * R) * s = V_avg * R - V_avg

s = V_avg * (R - 1) / (V_max - V_min * R + V_avg * (R - 1))
```

> if `s` is greater than 1, then V_max / V_min is already smaller than `R`, results then will not be changed.

The final matching pool distribution can be calculated as follows:

```js
// Rounding / negative values will be taken care in the smart contract
V_n_final = (V_n - V_avg) * s + V_avg

// Sigma(V_n_final) == Sigma(V_n) == V_sum

matching_n = TotalMatchingPool * V_n_final / V_sum
```

- The algorithm will round down whenever needed. It keeps total weights less than 1 (might be slightly smaller than 1). The error will be within `N * 10^-6` votes.
- The algorithm requires that each project receives at least one vote.
