module TestFFIDatasets

using LightGBM
using Test
using Random

# we don't want the LightGBM vom
redirect_stderr()

verbosity = "verbose=-1"


@testset "LGBM_BoosterCreate" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    @test booster.handle != C_NULL

end


@testset "LGBM_BoosterCreateFromModelfile" begin

    booster = LightGBM.LGBM_BoosterCreateFromModelfile(joinpath(@__DIR__, "data", "test_tree"))
    @test booster.handle != C_NULL

end


@testset "LGBM_BoosterLoadModelFromString" begin

    load_str = read(joinpath(@__DIR__, "data", "test_tree"), String)
    booster = LightGBM.LGBM_BoosterLoadModelFromString(load_str)
    @test booster.handle != C_NULL

end


@testset "LGBM_BoosterFree" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    # These tests exposed a double-free
    @test LightGBM.LGBM_BoosterFree(booster) == nothing
    @test booster.handle == C_NULL

end


@testset "LGBM_BoosterMerge" begin

    booster1 = LightGBM.LGBM_BoosterCreateFromModelfile(joinpath(@__DIR__, "data", "test_tree"))
    booster2 = LightGBM.LGBM_BoosterCreateFromModelfile(joinpath(@__DIR__, "data", "test_tree"))

    @test booster1.handle != booster2.handle

    # record the pointer values so we can verify they dont get mutated as part of the ops
    handle1 = UInt64(booster1.handle)
    handle2 = UInt64(booster2.handle)

    @test LightGBM.LGBM_BoosterMerge(booster1, booster2) == nothing

    @test booster1.handle != C_NULL
    @test booster2.handle != C_NULL

    @test UInt64(booster1.handle) == handle1
    @test UInt64(booster2.handle) == handle2

    @test booster1.handle != booster2.handle

end


@testset "LGBM_BoosterAddValidData" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    v_dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat .+ 1., verbosity)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    @test LightGBM.LGBM_BoosterAddValidData(booster, v_dataset) == nothing
    @test v_dataset.handle in getfield.(booster.datasets, :handle)
    @test length(booster.datasets) == 2

end


@testset "LGBM_BoosterResetTrainingData" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    e_dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat .+ 1., verbosity)
    v_dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat .+ 2., verbosity)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    @test LightGBM.LGBM_BoosterResetTrainingData(booster, e_dataset) == nothing
    @test length(booster.datasets) == 1
    @test first(booster.datasets).handle == e_dataset.handle

    # rewrite it but add another dataset
    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)
    LightGBM.LGBM_BoosterAddValidData(booster, v_dataset)

    @test LightGBM.LGBM_BoosterResetTrainingData(booster, e_dataset) == nothing
    @test length(booster.datasets) == 2
    @test first(booster.datasets).handle == e_dataset.handle
    @test last(booster.datasets).handle == v_dataset.handle

end


@testset "LGBM_BoosterGetNumClasses" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    v_dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat .+ 1., verbosity)

    for n in 2:20

        booster = LightGBM.LGBM_BoosterCreate(dataset, "objective=multiclass num_class=$(n) $verbosity")

        @test LightGBM.LGBM_BoosterGetNumClasses(booster) == n

    end

end


@testset "LGBM_BoosterUpdateOneIter" begin

    mymat = [2. 1.; 4. 3.; 5. 6.; 3. 4.; 6. 5.; 2. 1.]
    labels = [1.f0, 0.f0, 1.f0, 1.f0, 0.f0, 0.f0]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    LightGBM.LGBM_DatasetSetField(dataset, "label", labels)
    # default params won't allow this to learn anything from this useless data set (i.e. splitting completes)
    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    finished = LightGBM.LGBM_BoosterUpdateOneIter(booster)
    @test finished == 1
    finished = LightGBM.LGBM_BoosterUpdateOneIter(booster)
    @test finished == 1 # just checking nothing silly happens if you try to continue

    # Feed the tree nuts data so it has a hard time learning
    mymat = randn(1000, 2)
    labels = randn(1000)
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    LightGBM.LGBM_DatasetSetField(dataset, "label", labels)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)
    finished = LightGBM.LGBM_BoosterUpdateOneIter(booster)
    @test finished == 0

end


@testset "LGBM_BoosterRollbackOneIter" begin

    # I don't know how to test this, needs thought
    @test_broken false

end


@testset "LGBM_BoosterGetCurrentIteration" begin

    mymat = [2. 1.; 4. 3.; 5. 6.; 3. 4.; 6. 5.; 2. 1.]
    labels = [1.f0, 0.f0, 1.f0, 1.f0, 0.f0, 0.f0]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    LightGBM.LGBM_DatasetSetField(dataset, "label", labels)
    # default params won't allow this to learn anything from this useless data set (i.e. splitting completes)
    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    # check its finished
    @test LightGBM.LGBM_BoosterUpdateOneIter(booster) == 1

    for i in 1:10

        # Iteration number shouldn't increment cause we're not adding any more trees
        LightGBM.LGBM_BoosterUpdateOneIter(booster)
        @test LightGBM.LGBM_BoosterGetCurrentIteration(booster) == 1

    end

    # do again with nuts data
    mymat = randn(1000, 2)
    labels = randn(1000)
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)
    LightGBM.LGBM_DatasetSetField(dataset, "label", labels)

    # deliberately constrain the trees to ensure it can't converge by 10 gradient boosts by small chance
    booster = LightGBM.LGBM_BoosterCreate(dataset, "max_depth=1 num_leaf=2 $verbosity")

    for i in 1:10

        LightGBM.LGBM_BoosterUpdateOneIter(booster)
        @test LightGBM.LGBM_BoosterGetCurrentIteration(booster) == i

    end

end


@testset "LGBM_BoosterGetEvalCounts" begin

    # Unsure how to test
    @test_broken false

end


@testset "LGBM_BoosterGetEvalNames" begin

    # This is likely to get a segfaulty code too (must prealloc memory)
    @test_broken false

end


@testset "LGBM_BoosterGetFeatureNames" begin

    # This is likely to get a segfaulty code too (must prealloc memory)
    @test_broken false

end


@testset "LGBM_BoosterGetNumFeature" begin

    mymat = [1. 2.; 3. 4.; 5. 6.]
    dataset = LightGBM.LGBM_DatasetCreateFromMat(mymat, verbosity)

    booster = LightGBM.LGBM_BoosterCreate(dataset, verbosity)

    @test LightGBM.LGBM_BoosterGetNumFeature(booster) == 2

end


@testset "LGBM_BoosterGetEval" begin

    # Needs implementing
    @test_broken false

end


@testset "LGBM_BoosterGetNumPredict" begin

    # Needs implementing
    @test_broken false

end


@testset "LGBM_BoosterGetPredict" begin

    # Needs implementing
    @test_broken false

end


@testset "LGBM_BoosterCalcNumPredict" begin

    # Needs implementing
    @test_broken false

end


@testset "LGBM_BoosterPredictForMat" begin

    # Needs implementing
    @test_broken false

end


@testset "LGBM_BoosterSaveModel" begin

    # Needs implementing
    @test_broken false

end


end # module