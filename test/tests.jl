using Test

function test_fragmentvector()
    println("=== Tests FragmentVector ===")

    # Création basique
    f = FragmentVector{Int}(undef, 10)
    @test length(f) == 10

    # Test get/set simple
    for i in 1:10
        f[i] = i*10
    end
    for i in 1:10
        @test f[i] == i*10
    end

    # Test insert sur un indice vide
    f.map[5] = 0
    insert!(f, 5, 555)
    @test f[5] == 555

    # Test insert fusion gauche/droite/milieu
    # Préparer 2 blocs
    insert!(f, 2, 222)
    insert!(f, 8, 888)
    # Vérifier fusion
    insert!(f, 3, 333)  # devrait fusionner avec bloc de gauche
    insert!(f, 7, 777)  # devrait fusionner avec bloc de droite
    @test f[2] == 222
    @test f[3] == 333
    @test f[7] == 777
    @test f[8] == 888

    # Test prealloc_range
    r = prealloc_range!(f, 4:6)
    @test r == 4:6
    @test all(f.map[i] != 0 for i in r)

    # Test prealloc_range avec overlap
    r2 = prealloc_range!(f, 5:9)
    @test r2 == 7:9  # 5,6 déjà alloués
    @test all(f.map[i] != 0 for i in r2)

    # Test iterate complet
    vals = collect(f)
    @test length(vals) == length(f)

    # Test iterate sur subset via get_iterator
    subset = [2,3,7,8]
    iters = get_iterator(f, subset)
    # Vérifier que tous les éléments sont corrects
    for (block, idxs) in iters
        for idx in idxs
            @test block[idx] in vals
        end
    end

    # Test delete/reinsert (simulate remove + insert)
    f.map[5] = 0
    insert!(f, 5, 5555)
    @test f[5] == 5555

    # Stress test: 1000 inserts/removes aléatoires
    using Random
    rng = MersenneTwister(123)
    for _ in 1:1000
        idx = rand(rng, 1:length(f))
        val = rand(rng, 1:10000)
        if rand(rng) < 0.5
            f.map[idx] = 0  # remove
        else
            insert!(f, idx, val)
            @test f[idx] == val
        end
    end

    println("All tests passed!")
end

test_fragmentvector()