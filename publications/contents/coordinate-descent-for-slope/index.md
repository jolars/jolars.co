---
title: "Coordinate Descent for SLOPE"
author: 
  - Johan Larsson
  - Quentin Klopfenstein
  - Mathurin Massias
  - Jonas Wallin
date: 2022-10-26
type: preprint
repository: arXiv
arxiv: https://arxiv.org/abs/2210.14780
doi: 10.48550/arXiv.2210.14780
github: jolars/slopecd
---

## Abstract

The lasso is the most famous sparse regression and feature selection method. One reason for its popularity is the speed at which the underlying optimization problem can be solved. Sorted L-One Penalized Estimation (SLOPE) is a generalization of the lasso with appealing statistical properties. In spite of this, the method has not yet reached widespread interest. A major reason for this is that current software packages that fit SLOPE rely on algorithms that perform poorly in high dimensions. To tackle this issue, we propose a new fast algorithm to solve the SLOPE optimization problem, which combines proximal gradient descent and proximal coordinate descent steps. We provide new results on the directional derivative of the SLOPE penalty and its related SLOPE thresholding operator, as well as provide convergence guarantees for our proposed solver. In extensive benchmarks on simulated and real data, we show that our method outperforms a long list of competing algorithms.
