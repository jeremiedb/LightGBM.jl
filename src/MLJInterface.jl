module MLJInterface

import MLJModelInterface
import LightGBM


const LGBM_METRICS = (
    "None", "l1", "l2", "rmse", "quantile", "mape", "huber", "fair", "poisson", "gamma", "gamma_deviance",
    "tweedie", "ndcg", "lambdarank", "map", "mean_average_precision", "auc", "binary_logloss", "binary",
    "binary_error", "auc_mu", "multi_logloss", "multi_error", "cross_entropy", "xentropy", "multi_logloss",
    "multiclass", "softmax", "multiclassova", "multiclass_ova", "ova", "ovr", "cross_entropy_lambda",
    "xentlambda", "kullback_leibler", "kldiv",
)

const CLASSIFICATION_OBJECTIVES = (
    "binary", "multiclass", "softmax", "multiclassova", "multiclass_ova", "ova", "ovr",
)

const REGRESSION_OBJECTIVES = (
    "regression", "regression_l2", "l2", "mean_squared_error", "mse", "l2_root", "root_mean_squared_error", "rmse",
    "regression_l1", "l1", "mean_absolute_error", "mae", "huber", "fair", "poisson", "quantile", "mape",
    "mean_absolute_percentage_error", "gamma", "tweedie",
)


MLJModelInterface.@mlj_model mutable struct LGBMRegressor <: MLJModelInterface.Deterministic

    # Hyperparameters, see https://lightgbm.readthedocs.io/en/latest/Parameters.html for defaults
    num_iterations::Int = 10::(_ >= 0)
    learning_rate::Float64 = 0.1::(_ > 0.)
    num_leaves::Int = 31::(1 < _ <= 131072)
    max_depth::Int = -1;#::(_ != 0);
    tree_learner::String = "serial"::(_ in ("serial", "feature", "data", "voting"))
    histogram_pool_size::Float64 = -1.0;#::(_ != 0.0);
    min_data_in_leaf::Int = 20::(_ >= 0)
    min_sum_hessian_in_leaf::Float64 = 1e-3::(_ >= 0.0)
    lambda_l1::Float64 = 0.0::(_ >= 0.0)
    lambda_l2::Float64 = 0.0::(_ >= 0.0)
    min_gain_to_split::Float64 = 0.0::(_ >= 0.0)
    feature_fraction::Float64 = 1.0::(0.0 < _ <= 1.0)
    feature_fraction_seed::Int = 2
    bagging_fraction::Float64 = 1.0::(0.0 < _ <= 1.0)
    bagging_freq::Int = 0::(_ >= 0)
    bagging_seed::Int = 3
    early_stopping_round::Int = 0
    max_bin::Int = 255::(_ > 1)
    init_score::String = ""

    # Model properties
    objective::String = "regression"::(_ in REGRESSION_OBJECTIVES)
    categorical_feature::Vector{Int} = Vector{Int}()
    data_random_seed::Int = 1
    is_sparse::Bool = true
    is_unbalance::Bool = false

    # Metrics
    metric::Vector{String} = ["l2"]::(all(in.(_, (LGBM_METRICS, ))))
    metric_freq::Int = 1::(_ > 0)
    is_training_metric::Bool = false
    ndcg_at::Vector{Int} = Vector{Int}([1, 2, 3, 4, 5])::(all(_ .> 0))

    # Implementation parameters
    num_machines::Int = 1::(_ > 0)
    num_threads::Int  = 0::(_ >= 0)
    local_listen_port::Int = 12400::(_ > 0)
    time_out::Int = 120::(_ > 0)
    machine_list_file::String = ""
    save_binary::Bool = false
    device_type::String = "cpu"::(_ in ("cpu", "gpu"))

end


MLJModelInterface.@mlj_model mutable struct LGBMClassifier <: MLJModelInterface.Probabilistic

    # Hyperparameters, see https://lightgbm.readthedocs.io/en/latest/Parameters.html for defaults
    num_iterations::Int = 10::(_ >= 0)
    learning_rate::Float64 = 0.1::(_ > 0.)
    num_leaves::Int = 31::(1 < _ <= 131072)
    max_depth::Int = -1;#::(_ != 0);
    tree_learner::String = "serial"::(_ in ("serial", "feature", "data", "voting"))
    histogram_pool_size::Float64 = -1.0;#::(_ != 0.0);
    min_data_in_leaf::Int = 20::(_ >= 0)
    min_sum_hessian_in_leaf::Float64 = 1e-3::(_ >= 0.0)
    lambda_l1::Float64 = 0.0::(_ >= 0.0)
    lambda_l2::Float64 = 0.0::(_ >= 0.0)
    min_gain_to_split::Float64 = 0.0::(_ >= 0.0)
    feature_fraction::Float64 = 1.0::(0.0 < _ <= 1.0)
    feature_fraction_seed::Int = 2
    bagging_fraction::Float64 = 1.0::(0.0 < _ <= 1.0)
    bagging_freq::Int = 0::(_ >= 0)
    bagging_seed::Int = 3
    early_stopping_round::Int = 0
    max_bin::Int = 255::(_ > 1)
    init_score::String = ""

    # For documentation purposes: A calibration scaling factor for the output probabilities for binary and multiclass OVA
    # Not included above because this is only present for the binary model in the FFI wrapper, hence commented out
    # sigmoid::Float64 = 1.0::(_ > 0.0 )

    # Model properties
    objective::String = "multiclass"::(_ in CLASSIFICATION_OBJECTIVES)
    categorical_feature::Vector{Int} = Vector{Int}();
    data_random_seed::Int = 1
    is_sparse::Bool = true
    is_unbalance::Bool = false

    # Metrics
    metric::Vector{String} = ["None"]::(all(in.(_, (LGBM_METRICS, ))))
    metric_freq::Int = 1::(_ > 0)
    is_training_metric::Bool = false
    ndcg_at::Vector{Int} = Vector{Int}([1, 2, 3, 4, 5])::(all(_ .> 0))

    # Implementation parameters
    num_machines::Int = 1::(_ > 0)
    num_threads::Int  = 0::(_ >= 0)
    local_listen_port::Int = 12400::(_ > 0)
    time_out::Int = 120::(_ > 0)
    machine_list_file::String = ""
    save_binary::Bool = false
    device_type::String = "cpu"::(_ in ("cpu", "gpu"))

end


MODELS = Union{LGBMClassifier, LGBMRegressor}


function mlj_to_kwargs(model::LGBMRegressor)

    return Dict{Symbol, Any}(
        name => getfield(model, name)
        for name in fieldnames(typeof(model))
    )

end

function mlj_to_kwargs(model::LGBMClassifier, classes)

    num_class = length(classes)
    if model.objective == "binary"
        if num_class != 2
            throw(ArgumentError("binary objective number of classes $num_class greater than 2"))
        end
        # munge num_class for LightGBM
        num_class = 1
    end

    retval = Dict{Symbol, Any}(
        name => getfield(model, name)
        for name in fieldnames(typeof(model))
    )

    retval[:num_class] = num_class
    return retval

end

# X and y and w must be untyped per MLJ docs
function fit(mlj_model::MODELS, verbosity::Int, X, y, w=Vector{AbstractFloat}())

    # MLJ docs are clear that 0 means silent. but 0 in LightGBM world means "warnings"
    # and < 0 means fatal logs only, so we put intended silence to -1 (which is probably the closest we get)
    verbosity = if verbosity == 0; -1 else verbosity end

    y_lgbm, classes = prepare_targets(y, mlj_model)
    model = model_init(mlj_model, classes)
    X = MLJModelInterface.matrix(X)
    # The FFI wrapper wants Float32 for these
    w = Float32.(w)
    report = LightGBM.fit!(model, X, y_lgbm; verbosity=verbosity, weights=w)

    model = (model, classes)
    cache = nothing
    report = (report,)

    # Caution: The model is a pointer to a memory location including its training data
    # This definitely needs fixing
    return (model, cache, report)

end


# This does prep for classification tasks
@inline function prepare_targets(targets, model::LGBMClassifier)

    classes = MLJModelInterface.classes(first(targets))
    # -1 because these will be 1,2 and LGBM uses the 0/1 boundary
    # -This also works for multiclass because the classes are 0 indexed
    targets = Float64.(MLJModelInterface.int(targets) .- 1)
    return targets, classes

end
# This does prep for Regression, which is basically a no-op (or rather, just creation of an empty placeholder classes object
@inline prepare_targets(targets::AbstractVector, model::LGBMRegressor) = targets, []


function predict_classifier((fitted_model, classes), Xnew)

    Xnew = MLJModelInterface.matrix(Xnew)
    predicted = LightGBM.predict(fitted_model, Xnew)
    # when the objective == binary, lightgbm internally has classes = 1 and spits out only probability of positive class
    if size(predicted, 2) == 1
        predicted = hcat(1. .- predicted, predicted)
    end

    return [MLJModelInterface.UnivariateFinite(classes, predicted[row, :]) for row in 1:size(predicted, 1)]

end

function predict_regression((fitted_model, classes), Xnew)

    Xnew = MLJModelInterface.matrix(Xnew)
    return LightGBM.predict(fitted_model, Xnew)

end


# multiple dispatch the various signatures for each model and args combo
MLJModelInterface.fit(model::MLJInterface.MODELS, verbosity::Int, X, y) = MLJInterface.fit(model, verbosity, X, y)
MLJModelInterface.fit(model::MLJInterface.MODELS, verbosity::Int, X, y, w::Nothing) = MLJInterface.fit(model, verbosity, X, y)
MLJModelInterface.fit(model::MLJInterface.MODELS, verbosity::Int, X, y, w) = MLJInterface.fit(model, verbosity, X, y, w)

MLJModelInterface.predict(model::MLJInterface.LGBMClassifier, fitresult, Xnew) = MLJInterface.predict_classifier(fitresult, Xnew)
MLJModelInterface.predict(model::MLJInterface.LGBMRegressor, fitresult, Xnew) = MLJInterface.predict_regression(fitresult, Xnew)

# multiple dispatch the model initialiser functions
model_init(mlj_model::MLJInterface.LGBMClassifier, classes) = LightGBM.LGBMClassification(; mlj_to_kwargs(mlj_model, classes)...)
model_init(mlj_model::MLJInterface.LGBMRegressor, targets) = LightGBM.LGBMRegression(; mlj_to_kwargs(mlj_model)...)


# metadata
MLJModelInterface.metadata_pkg.(
    (LGBMClassifier, LGBMRegressor); # end positional args
    name="LightGBM",
    uuid="7acf609c-83a4-11e9-1ffb-b912bcd3b04a",
    url="https://github.com/IQVIA-ML/LightGBM.jl",
    julia=false,
    license="MIT Expat",
    is_wrapper=true,
)


MLJModelInterface.metadata_model(
    LGBMClassifier; # end positional args
    path="LightGBM.MLJInterface.LGBMClassifier",
    input=MLJModelInterface.Table(MLJModelInterface.Continuous),
    target=AbstractVector{<:MLJModelInterface.Finite},
    weights=true,
    descr="Microsoft LightGBM FFI wrapper: Classifier",
)

MLJModelInterface.metadata_model(
    LGBMRegressor; # end positional args
    path="LightGBM.MLJInterface.LGBMRegressor",
    input=MLJModelInterface.Table(MLJModelInterface.Continuous),
    target=AbstractVector{MLJModelInterface.Continuous},
    weights=true,
    descr="Microsoft LightGBM FFI wrapper: Regressor",
)

end # module