# Numerical helpers shared by several recommendations. Nothing here is exported.

using SpecialFunctions: erfc, erfcinv

"""
    Q(x)

Complementary cumulative distribution function of the standard normal distribution, as defined in Recommendation ITU-R P.1057.
"""
Q(x::Real) = erfc(x / sqrt(2)) / 2

"""
    Qinv(p)

Inverse of [`Q`](@ref); valid for `0 < p < 1`.
"""
Qinv(p::Real) = sqrt(2) * erfcinv(2p)

# Standard normal cumulative distribution function
Φ(z::Real) = Q(-z)

"""
    bisect(f, lo, hi; xtol = 1e-12, maxiter = 200)

Root of `f` on `[lo, hi]` by bisection. `f(lo)` and `f(hi)` must have opposite signs, otherwise an `ArgumentError` is thrown. Stops when the bracket half-width is below `xtol` or after `maxiter` iterations.
"""
function bisect(f, lo::Real, hi::Real; xtol::Real = 1e-12, maxiter::Integer = 200)
    lo, hi = float(lo), float(hi)
    flo = f(lo)
    fhi = f(hi)
    iszero(flo) && return lo
    iszero(fhi) && return hi
    sign(flo) == sign(fhi) && throw(ArgumentError("bisect requires a sign change on [lo, hi]: f($lo) = $flo, f($hi) = $fhi"))
    for _ in 1:maxiter
        mid = (lo + hi) / 2
        fmid = f(mid)
        (iszero(fmid) || (hi - lo) / 2 < xtol) && return mid
        if sign(fmid) == sign(flo)
            lo, flo = mid, fmid
        else
            hi = mid
        end
    end
    return (lo + hi) / 2
end

# Gauss-Legendre abscissae and weights on [-1, 1] (positive half only; the other half is mirrored)
const GL6_W = (0.1713244923791705, 0.3607615730481384, 0.4679139345726904)
const GL6_X = (0.9324695142031522, 0.6612093864662647, 0.2386191860831970)
const GL12_W = (0.04717533638651177, 0.1069393259953183, 0.1600783285433464, 0.2031674267230659, 0.2334925365383547, 0.2491470458134029)
const GL12_X = (0.9815606342467191, 0.9041172563704750, 0.7699026741943050, 0.5873179542866171, 0.3678314989981802, 0.1252334085114692)
const GL20_W = (0.01761400713915212, 0.04060142980038694, 0.06267204833410906, 0.08327674157670475, 0.1019301198172404, 0.1181945319615184, 0.1316886384491766, 0.1420961093183821, 0.1491729864726037, 0.1527533871307259)
const GL20_X = (0.9931285991850949, 0.9639719272779138, 0.9122344282513259, 0.8391169718222188, 0.7463319064601508, 0.6360536807265150, 0.5108670019508271, 0.3737060887154196, 0.2277858511416451, 0.07652652113349733)

"""
    bivariate_normal_ccdf(a, b, ρ)

Probability that `X > a` and `Y > b` for a standard bivariate normal pair with correlation `ρ`. This is the complementary bivariate normal distribution used in Recommendations ITU-R P.618 (sections 2.2.1.2 and 2.2.4.1) and P.1815.

Implements the algorithm of A. Genz, "Numerical computation of rectangular bivariate and trivariate normal and t probabilities", Statistics and Computing 14 (2004), which refines Drezner and Wesolowsky (1989); absolute accuracy is about 1e-14.
"""
function bivariate_normal_ccdf(a::Real, b::Real, ρ::Real)
    (a == Inf || b == Inf) && return 0.0
    a == -Inf && return b == -Inf ? 1.0 : Φ(-b)
    b == -Inf && return Φ(-a)
    -1 <= ρ <= 1 || throw(ArgumentError("correlation must be in [-1, 1], got $ρ"))
    ρ == 0 && return Φ(-a) * Φ(-b)
    w, x = if abs(ρ) < 0.3
        GL6_W, GL6_X
    elseif abs(ρ) < 0.75
        GL12_W, GL12_X
    else
        GL20_W, GL20_X
    end
    tp = 2π
    h = float(a)
    k = float(b)
    hk = h * k
    bvn = 0.0
    if abs(ρ) < 0.925
        hs = (h * h + k * k) / 2
        asr = asin(ρ) / 2
        for i in eachindex(w), s in (-1, 1)
            sn = sin(asr * (1 + s * x[i]))
            bvn += w[i] * exp((sn * hk - hs) / (1 - sn * sn))
        end
        bvn = bvn * asr / tp + Φ(-h) * Φ(-k)
    else
        if ρ < 0
            k = -k
            hk = -hk
        end
        if abs(ρ) < 1
            as = 1 - ρ * ρ
            α = sqrt(as)
            bs = (h - k)^2
            asr = -(bs / as + hk) / 2
            c = (4 - hk) / 8
            d = (12 - hk) / 80
            if asr > -100
                bvn = α * exp(asr) * (1 - c * (bs - as) * (1 - d * bs) / 3 + c * d * as * as)
            end
            if hk > -100
                bb = sqrt(bs)
                sp = sqrt(tp) * Φ(-bb / α)
                bvn -= exp(-hk / 2) * sp * bb * (1 - c * bs * (1 - d * bs) / 3)
            end
            α /= 2
            acc = 0.0
            for i in eachindex(w), s in (-1, 1)
                xs = (α * (1 + s * x[i]))^2
                asr1 = -(bs / xs + hk) / 2
                if asr1 > -100
                    sp = 1 + c * xs * (1 + 5 * d * xs)
                    rs = sqrt(1 - xs)
                    ep = exp(-(hk / 2) * xs / (1 + rs)^2) / rs
                    acc += w[i] * exp(asr1) * (sp - ep)
                end
            end
            bvn = (α * acc - bvn) / tp
        end
        if ρ > 0
            bvn += Φ(-max(h, k))
        elseif h >= k
            bvn = -bvn
        else
            L = h < 0 ? Φ(k) - Φ(h) : Φ(-h) - Φ(-k)
            bvn = L - bvn
        end
    end
    return clamp(bvn, 0.0, 1.0)
end
