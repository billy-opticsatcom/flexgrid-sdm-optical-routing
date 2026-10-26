# Research framework

This document describes *how* the study was carried out: how the problem was decomposed, how each design
question was answered, and how the results were verified. Numerical values and implementation details
are withheld; see the [README](../README.md#what-is-public-and-what-is-withheld).

## 1. Start from requirements, not from a design

Before any experiment was run, the study fixed a set of measurable acceptance criteria. Each criterion is
a check the code performs on itself:

| Area | Criterion (form) |
|---|---|
| Spectrum model | The slot-count formula reproduces the operator modulation table exactly, row by row |
| Graph analysis | Self-implemented centralities match MATLAB reference values to numerical precision |
| Dimensioning | The restructured OXC dimensioning reproduces the earlier model exactly |
| Backward compatibility | Legacy mode reproduces the earlier simulator's blocking to many significant digits |
| Routing | K-shortest paths are loopless, distinct, sorted by cost, and the first is optimal |
| Resource accounting | No spectrum leak or transceiver/OXC drift after every request has departed, across all model variants |
| Symmetry | On an empty network, Last-Fit mirrors First-Fit, so blocking must be identical |
| Physical layer | The GN-model reach is calibrated against the reach table within a stated margin |
| Reproducibility | Fixed seeds; repeated runs give identical results |

Vague goals such as "efficient routing" were deliberately avoided: a requirement the code cannot test is
a requirement nobody can verify.

## 2. Decompose into design questions

The system was split into seven stages, each answering one question (see the table in the README). Each
stage reads only the verified outputs of earlier stages. This keeps errors local: a wrong slot count is
caught in stage 2, not discovered later as an unexplained blocking difference.

## 3. Model the network as a route graph

The backbone is treated as a weighted graph whose structure drives every later decision:

- **Edges** carry a spectrum × core occupancy state. Feasibility of a lightpath is a set operation on the
  edges of its route (continuity), on a contiguous slot range (contiguity) and on one core
  (core continuity).
- **Nodes** carry finite resources. A lightpath of *h* hops consumes switching capacity at *h + 1* nodes,
  two of them for add/drop and the rest for transit, so the route graph determines where switching
  demand appears.
- **Graph measures** (degree, closeness, betweenness, PageRank, eigenvector) describe how traffic is
  expected to flow through each node, and are candidate inputs to node dimensioning.

## 4. Treat physics and mathematics identities as tests

Alongside the acceptance criteria, known results are asserted, for example:

- Required SNR for each modulation format follows from its BER expression at the FEC threshold.
- Each amplified span operated at its optimum launch power is also optimal for the whole path under
  incoherent noise accumulation, so path GSNR is the reciprocal sum of span SNRs.
- Slot counts follow directly from bit rate, bits per symbol, polarisations, FEC overhead and roll-off.
- Removing all traffic returns every resource to its initial value.

## 5. Record every design change with its evidence

Several assumptions did not survive testing. Each change was written into a change log stating the
observation, the experiment that resolved it and the resulting rule. The questions that drove the most
important decisions were:

1. **Static or adaptive routing.** Is precomputed K-shortest-path routing enough, or does reacting to the
   current network state pay off, and at which loads?
2. **What blocks first.** Is blocking caused by spectrum, by transceivers, by node switching capacity or
   by signal quality, and does the answer change with load?
3. **Which graph measure to trust.** Which structural property of a node predicts its switching demand,
   and does mixing measures help?
4. **Optimiser honesty.** How must a simulation-in-the-loop optimiser be trained and validated so that it
   does not overfit one traffic realisation or exploit a modelling loophole?
5. **Reach table or physics.** How conservative is an operator reach table compared with a GN-model
   estimate, and how much does that choice move the results?
6. **Where SDM pays off.** Which corridors and demand classes limit the network once a second band or
   extra cores are added?

The answers, and the experiments behind them, are part of the withheld material.

## 6. Compare against baselines, never in isolation

Every chosen technique was evaluated alongside simpler alternatives and, where possible, an optimised
reference:

| Topic | Compared |
|---|---|
| Routing | Adaptive re-routing heuristic, K-shortest paths with K = 3 and K = 5 |
| Spectrum assignment | First-Fit, Best-Fit, Last-Fit, Random-Fit |
| Path selection | First feasible, lowest starting slot, minimum fragmentation |
| Node dimensioning | Even split, five single centralities, mixed centralities, GWO- and WOA-optimised splits |
| Physical layer | Reach table, closed-form GN model |
| Line system | C band, C+L band, C+L band over multi-core fibre |

## 7. Experimental protocol

- **Common random numbers.** For each load and seed, every scenario sees exactly the same traffic, so
  differences come from the scenario rather than from noise.
- **Multiple seeds.** Results are reported as the mean with a Student-t 95 % confidence interval; batch
  means give a within-run interval as well.
- **Steady state.** A warm-up of several holding times is excluded from every metric.
- **Train/validate split for optimisation.** Optimisers are trained on a few traffic realisations and
  every strategy is then compared on unseen realisations.
- **Blocking by cause and by class.** Each rejected request is attributed to the resource that blocked
  it, and blocking is reported per bit-rate class to expose unfairness against high-rate demands.

## 8. Known limitations

The GN model assumes Nyquist WDM, full load in each band, identical fibre on all links and no inter-band
stimulated Raman scattering. Multi-core fibre is modelled without inter-core crosstalk, which suits
low-crosstalk trench-assisted designs but not coupled-core fibre. Time advances in integer units, and
traffic is synthetic rather than operator data. Absolute reach would need an enhanced GN model or a
GNPy cross-check. These define the next steps of the research.
