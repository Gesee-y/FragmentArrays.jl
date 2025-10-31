using Test
using Random

function test_fragmentvector()
    @testset "Creation" begin

    f = FragmentVector{Int}(undef, 10)
    @test length(f) == 10

    for i in 1:10
        f[i] = i*10
    end
    for i in 1:10
        @test f[i] == i*10
    end

    deleteat!(f, 5)
    insert!(f, 5, 555)
    @test f[5] == 555

    end

    @testset "Fragment fusion" begin

    f = FragmentVector{Int}(undef, 10)

    f[2] = 222
    f[8] = 888
    
    f[3] = 333 
    f[7] = 777 

    @test f[2] == 222
    @test f[3] == 333
    @test f[7] == 777
    @test f[8] == 888

    end

    @testset "Blocks preallocation" begin

    f = FragmentVector{Int}(undef, 10)

    r = prealloc_range!(f, 4:6)
    @test r == 4:6
    @test all(f.map[i] != 0 for i in r)

    r2 = prealloc_range!(f, 5:9)
    @test r2 == 7:9  # 5,6 déjà alloués
    @test all(f.map[i] != 0 for i in r2)

    # Test iterate complet
    vals = collect(f)
    @test length(vals) == length(f)

    # Test iterate sur subset via get_iterator
    subset = [2,3,4,5,6,7,8]
    iters = get_iterator_range(f, subset)
    # Vérifier que tous les éléments sont corrects
    for (block, idxs) in iters
        for idx in idxs
            @test block[idx] in vals
        end
    end

    end

    @testset "Selete/reinsert" begin

    f = FragmentVector{Int}(undef, 10)

    f[5] = 5555
    @test f[5] == 5555

    # Stress test: 1000 inserts/removes aléatoires
    
    rng = MersenneTwister(123)
    for _ in 1:1000
        idx = rand(rng, 1:length(f))
        val = rand(rng, 1:10000)
        r = rand(rng)
        if r < 0.5
            deleteat!(f, idx)  # remove
        else
            f[idx] = val
            @test f[idx] == val
        end
    end

    end
end

test_fragmentvector()