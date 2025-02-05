<h1 align="center">SIRUS.jl</h1>

<h3 align="center">
    Interpretable Machine Learning via Rule Extraction
</h3>

<p align="center">
    <a href="https://github.com/rikhuijzer/SIRUS.jl/actions?query=workflow%3ACI+branch%3Amain">
        <img src="https://github.com/rikhuijzer/SIRUS.jl/workflows/CI/badge.svg" alt="CI">
    </a>
    <a href="https://github.com/invenia/BlueStyle">
        <img src="https://img.shields.io/badge/Code%20Style-Blue-4495d1.svg" alt="Code Style Blue">
    </a>
    <a href="https://zenodo.org/badge/latestdoi/567665496">
        <img src="https://zenodo.org/badge/567665496.svg" alt="DOI">
    </a>
</p>

<br>

This package is a pure Julia implementation of the **S**table and **I**nterpretable **RU**le **S**ets (SIRUS) algorithm.
The algorithm was originally created by Clément Bénard, Gérard Biau, Sébastien Da Veiga, and Erwan Scornet (Bénard et al., [2021](http://proceedings.mlr.press/v130/benard21a.html)).
`SIRUS.jl` has implemented both classification and regression, but we found that performance is generally best on classification tasks.

# Installation

```julia
julia> ]

pkg> add SIRUS
```

# Getting Started

This package defines two rule-based models that satisfy the Machine Learning Julia [`MLJ.jl`](https://github.com/alan-turing-institute/MLJ.jl) interface.
The models are `StableRulesClassifier` and `StableRulesRegressor`:

## Example

```julia
julia> using MLJ, SIRUS

julia> X, y = make_blobs(200, 10; centers=2);

julia> model = StableRulesClassifier();

julia> mach = machine(model, X, y);

julia> fit!(mach);
```

See `?StableRulesClassifier`, `?StableRulesRegressor`, or the [API documentation](https://sirus.jl.huijzer.xyz/dev/api/) for more information about the models and their hyperparameters.
A full guide through binary classification can be found in the [Simple Binary Classification](https://sirus.jl.huijzer.xyz/dev/binary-classification/) example.

# Documentation

Documentation is at [sirus.jl.huijzer.xyz](https://sirus.jl.huijzer.xyz).

# Contributing

Thank you for your interest in contributing to SIRUS.jl!
There are multiple ways to contribute.

## Questions and Bug Reports

For questions or bug reports, you can open an [issue](https://github.com/rikhuijzer/SIRUS.jl/issues).
Questions can also be asked at the [Julia forum](https://discourse.julialang.org/) or by sending a mail to [github@huijzer.xyz](mailto:github@huijzer.xyz).
Tag `@rikh` in the forum to ensure a quick reply.

## Pull Requests

To submit patches, use pull requests (PRs) here on GitHub.
In general:

- Try to keep PRs limited to one feature or bug; otherwise they become hard to review/verify.
- Try to use the code style that is used in the rest of the codebase.
  See also the [Code Style Blue](https://github.com/invenia/BlueStyle).
- Try to update documentation when updating code, but feel free to leave documentation updates for a separate PR.
- When possible, make PRs as easily reversible as possible.
  Any change that would be easily reversible later provides little risk and can, therefore, more easily be merged.

As long as the PR moves the codebase forward, merging will likely happen.
