n = 200
rng = StableRNG(1)
X, y = make_moons(n; rng, shuffle=true)

rng = StableRNG(1)
model = StableForestClassifier(; rng)
mach = machine(model, X, y)
fit!(mach; verbosity=0)

preds = predict(mach)
@show auc(preds, y)
@test 0.0 < auc(preds, y)

resampling = CV(; shuffle=true, rng)
@show evaluate(model, X, y; verbosity=0, resampling, measure=auc)

rng = StableRNG(1)
rulesmodel = StableRulesClassifier(; rng)
rulesmach = machine(rulesmodel, X, y)
fit!(rulesmach; verbosity=0)

@show auc(preds, y)
@test 0.0 < auc(preds, y)

resampling = CV(; shuffle=true, rng)
@show evaluate(rulesmodel, X, y; verbosity=0, resampling, measure=auc)
