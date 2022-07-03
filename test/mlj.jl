n = 1000
rng = StableRNG(1)
X, y = make_moons(n; rng, shuffle=true)

function _evaluate(rng, model)
    resampling = CV(; shuffle=true, rng)
    evaluate(model, X, y; verbosity=0, resampling, measure=auc)
end

rng = StableRNG(1)
# n = 1000 with CV gives an AUC of 0.98.
# @show _evaluate(rng, RandomForestClassifier(; max_depth=2))
# @show _evaluate(rng, LGBMClassifier(; max_depth=2))

rng = StableRNG(1)
model = StableForestClassifier(; rng)
mach = machine(model, X, y)
fit!(mach; verbosity=0)

preds = predict(mach)
@show auc(preds, y)
@test 0.0 < auc(preds, y)

rng = StableRNG(1)
@show _evaluate(rng, StableForestClassifier(; rng))

rng = StableRNG(1)
rulesmodel = StableRulesClassifier(; rng)
rulesmach = machine(rulesmodel, X, y)
fit!(rulesmach; verbosity=0)

@show auc(preds, y)
@test 0.0 < auc(preds, y)

rng = StableRNG(1)
# @show _evaluate(rng, StableRulesClassifier(; rng))
