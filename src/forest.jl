"""
    _gini(y::AbstractVector, classes::AbstractVector)

Return the Gini index for a vector outcomes `y` and `classes`.
Here, `y` is usually a view on the outcome values in some region.
Inside that region, `gini` is a measure of node purity.
If all values in the region have the same class, then gini is zero.
The equation is mentioned on Wikipedia as
``1 - \\sum{class \\in classes} p_i^2``
for ``p_i`` be the fraction (proportion) of items labeled with class ``i`` in the set.
"""
function _gini(y::AbstractVector)
    classes = unique(y)
    len_y = length(y)
    impurity = 1.0
    for class in classes
        proportion = count(y .== class) / len_y
        impurity -= proportion^2
    end
    return impurity
end

"""
Return a rough estimate for the index of the cutpoint.
Choose the highest suitable index if there is more than one suitable index.
The reason is that this will split the data nicely in combination with the `<` used later on.
For example, for [1, 2, 3, 4], both 2 and 3 satisfy the 0.5 quantile.
In this case, we pick the ceil, so 3.
Next, the tree will split on 3, causing left (<) to contain 1 and 2 and right (≥) to contain 3 and 4.
"""
_rough_cutpoint_index_estimate(n::Int, quantile::Real) = Int(ceil(quantile * n))

"Return the empirical `quantile` for data `V`."
function _empirical_quantile(V::AbstractVector, quantile::Real)
    @assert 0.0 ≤ quantile ≤ 1.0
    n = length(V)
    index = _rough_cutpoint_index_estimate(n, quantile)
    if index == 0
        index = 1
    end
    if index == n + 1
        index = n
    end
    sorted = sort(V)
    return Float(sorted[index])
end

"Return a vector of `q` cutpoints taken from the empirical distribution from data `V`."
function _cutpoints(V::AbstractVector, q::Int)
    @assert 2 ≤ q
    quantiles = range(0.0; stop=1.0, length=q)
    return Float[_empirical_quantile(V, quantile) for quantile in quantiles]
end

"Return the number of features `p` in a dataset `X`."
_p(X::AbstractMatrix) = size(X, 2)
_p(X) = length(Tables.columnnames(X))

"Set of possible cutpoints, that is, numbers from the empirical quantiles."
const Cutpoints = Matrix{Float}

_view_feature(X::AbstractMatrix, feature::Int) = view(X, :, feature)
_view_feature(X, feature::Int) = X[feature]

"Return a matrix containing `q` rows and one column for each feature in the dataset."
function _cutpoints(X, q::Int)
    p = _p(X)
    cutpoints = Cutpoints(undef, q, p)
    for feature in 1:p
        V = _view_feature(X, feature)
        cutpoints[:, feature] = _cutpoints(V, q)
    end
    return cutpoints
end

"Return a view on all `y` for which the `comparison` holds in `X[:, feature]`."
function _view_y(X, y, feature::Int, comparison, cutpoint)
    indexes_in_region = comparison.(X[:, feature], cutpoint)
    return view(y, indexes_in_region)
end

"Location where the tree splits for some split."
struct SplitPoint
    feature::Int
    value::Float
end

function _information_gain(y, y_left, y_right)
    p = length(y_left) / length(y)
    starting_impurity = _gini(y)
    impurity_change = p * _gini(y_left) + (1 - p) * _gini(y_right)
    return starting_impurity - impurity_change
end

"""
Return the split for which the gini index is maximized.
This function receives the cutpoints for the whole dataset `D` because `X` can be a subset of `D`.
For a walkthrough of the CART algorithm, see https://youtu.be/LDRbO9a6XPU.
"""
function _split(
        X,
        y::AbstractVector,
        classes::AbstractVector,
        cutpoints::AbstractMatrix{Float}
    )
    best_score = Float(0)
    best_score_feature = 0
    best_score_cutpoint = Float(0)
    for feature in 1:_p(X)
        feature_cutpoints = view(cutpoints, :, feature)
        for cutpoint in feature_cutpoints
            y_left = _view_y(X, y, feature, <, cutpoint)
            length(y_left) == 0 && continue
            y_right = _view_y(X, y, feature, ≥, cutpoint)
            length(y_right) == 0 && continue
            gain = _information_gain(y, y_left, y_right)
            if best_score ≤ gain
                best_score = gain
                best_score_feature = feature
                best_score_cutpoint = cutpoint
            end
        end
    end
    if best_score == Float(0)
        return nothing
    end
    return SplitPoint(best_score_feature, best_score_cutpoint)
end

const Probabilities = Vector{Float64}

"""
    Leaf

Leaf of a decision tree.
The probabilities are based on the `y`'s falling into the region associated with this leaf.
"""
struct Leaf
    probabilities::Probabilities
end

function Leaf(classes, y)
    l = length(y)
    probabilities = [count(y .== class) / l for class in classes]
    # Not creating a UnivariateFinite because it requires MLJBase
    return Leaf(probabilities)
end

struct Node
    splitpoint::SplitPoint
    left::Union{Node, Leaf}
    right::Union{Node, Leaf}
end

children(node::Node) = [node.left, node.right]
nodevalue(node::Node) = node.splitpoint

"Return a view on all rows in `X` and `y` for which the `comparison` holds in `X[:, feature]`."
function _view_X_y(X, y, splitpoint::SplitPoint, comparison)
    indexes_in_region = comparison.(X[:, splitpoint.feature], splitpoint.value)
    X_view = view(X, indexes_in_region, :)
    y_view = view(y, indexes_in_region)
    return (X_view, y_view)
end

function _verify_lengths(X, y)
    l1 = size(X, 1)
    l2 = length(y)
    if l1 != l2
        error("Expected X and y to have the same number of rows, but got $l1 and $l2 rows")
    end
end

function _tree(
        X,
        y::AbstractVector,
        classes::AbstractVector=unique(y);
        depth=0,
        max_depth=2,
        q=10,
        cutpoints::AbstractMatrix{Float}=_cutpoints(X, q),
        min_data_in_leaf=5
    )
    if X isa Tables.MatrixTable
        error("Not implemented for arbitrary tables yet. Pass a matrix instead")
    end
    _verify_lengths(X, y)
    if depth == max_depth
        return Leaf(classes, y)
    end
    splitpoint = _split(X, y, classes, cutpoints)
    if isnothing(splitpoint) || length(y) < min_data_in_leaf
        return Leaf(classes, y)
    end
    depth += 1
    left = let
        _X, _y = _view_X_y(X, y, splitpoint, <)
        _tree(_X, _y, classes; cutpoints, depth)
    end
    right = let
        _X, _y = _view_X_y(X, y, splitpoint, ≥)
        _tree(_X, _y, classes; cutpoints, depth)
    end
    node = Node(splitpoint, left, right)
    return node
end

_predict(leaf::Leaf, x::AbstractVector) = leaf.probabilities

"""
Predict `y` for a data vector defined by `x`.
Also pass a vector if the data has only one feature.
"""
function _predict(node::Node, x::AbstractVector)
    feature = node.splitpoint.feature
    value = node.splitpoint.value
    if x[feature] < value
        return _predict(node.left, x)
    else
        return _predict(node.right, x)
    end
end
function _predict(node::Node, x::Union{Tables.MatrixRow, Tables.ColumnsRow})
    return _predict(node, collect(x))
end
function _predict(node::Node, X::AbstractMatrix)
    return _predict.(Ref(node), eachrow(X))
end

struct Forest{T}
    trees::Vector{Union{Node,Leaf}}
    classes::Vector{T}
end

"Increase the state of `rng` by `i`."
_change_rng_state!(rng::AbstractRNG, i::Int) = rand(rng, i)

"""
Return a random forest.

!!! note
    Each tree in a random forest is built by taking a random sample from the dataset (bootstrapped sample).
    And unlike in bagging, each tree also gets to see only a set of `m` randomly chosen features,
    where for some total number of features `p`, then `m = sqrt(p)` (James et al., [2014](https://doi.org/10.1007/978-1-0716-1418-1)).
"""
function _forest(
        rng::AbstractRNG,
        X::AbstractMatrix,
        y::AbstractVector;
        partial_sampling::Real=0.7,
        n_trees::Int=1_000,
        max_depth::Int=2,
        q::Int=10,
        min_data_in_leaf::Int=5
    )
    if 2 < max_depth
        error("Tree depth is too high. Rule filtering for a higher depth is not implemented.")
    end
    # It is essential for the stability to determine the cutpoints over the whole dataset.
    cutpoints = _cutpoints(X, q)
    classes = unique(y)

    n_features = round(Int, sqrt(_p(X)))
    n_samples = floor(Int, partial_sampling * length(y))

    trees = Vector{Union{Node,Leaf}}(undef, n_trees)
    for i in 1:n_trees
        _rng = copy(rng)
        _change_rng_state!(rng, i)
        cols = rand(_rng, 1:_p(X), n_features)
        rows = rand(_rng, 1:length(y), n_samples)
        _X = view(X, rows, cols)
        _y = view(y, rows)
        _cutpoints = view(cutpoints, :, cols)
        tree = _tree(
            _X,
            _y,
            classes;
            max_depth,
            q,
            cutpoints=_cutpoints,
            min_data_in_leaf
        )
        trees[i] = tree
    end
    return Forest(trees, classes)
end
function _forest(rng::AbstractRNG, X, y; kwargs...)
    if !(X isa AbstractMatrix || Tables.istable(X))
        error("Input `X` doesn't satisfy the Tables.jl interface.")
    end
    # Tables doesn't assume the data fits in memory so that complicates things a lot.
    # Implementing out-of-memory trees is a problem for later.
    return _forest(rng, Tables.matrix(X), y; kwargs...)
end

function _predict(forest::Forest, row::AbstractVector)
    probs = [_predict(tree, row) for tree in forest.trees]
    return _mean_probabilities(probs)
end

function _predict(forest::Forest, X::AbstractMatrix)
    probs = _predict.(Ref(forest), eachrow(X))
    P = reduce(hcat, probs)'
    return UnivariateFinite(forest.classes, P; pool=missing)
end

function _predict(forest::Forest, X)
    if !Tables.istable(X)
        error("Expected a Table")
    end
    return _predict(forest, Tables.matrix(X))
end
