using SparseDiffTools, ForwardDiff, FiniteDiff, Zygote, IterativeSolvers
using LinearAlgebra, Test

using Random
Random.seed!(123)
N = 300
const A = rand(N, N)
f(y, x) = mul!(y, A, x)
f(x) = A * x
x = rand(N)
v = rand(N)
a, b = rand(2)
dy = similar(x)
g(x) = sum(abs2, x)
function h(x)
    FiniteDiff.finite_difference_gradient(g, x)
end
function h(dy, x)
    FiniteDiff.finite_difference_gradient!(dy, g, x)
end

cache1 = ForwardDiff.Dual{typeof(ForwardDiff.Tag(SparseDiffTools.DeivVecTag(), eltype(x))),
                          eltype(x), 1}.(x, ForwardDiff.Partials.(Tuple.(v)))
cache2 = ForwardDiff.Dual{typeof(ForwardDiff.Tag(SparseDiffTools.DeivVecTag(), eltype(x))), eltype(x), 1}.(x, ForwardDiff.Partials.(Tuple.(v)))
@test num_jacvec!(dy, f, x, v)≈ForwardDiff.jacobian(f, similar(x), x) * v rtol=1e-6
@test num_jacvec!(dy, f, x, v, similar(v),
                  similar(v))≈ForwardDiff.jacobian(f, similar(x), x) * v rtol=1e-6
@test num_jacvec(f, x, v)≈ForwardDiff.jacobian(f, similar(x), x) * v rtol=1e-6

@test auto_jacvec!(dy, f, x, v) ≈ ForwardDiff.jacobian(f, similar(x), x) * v
@test auto_jacvec!(dy, f, x, v, cache1, cache2) ≈ ForwardDiff.jacobian(f, similar(x), x) * v
@test auto_jacvec(f, x, v) ≈ ForwardDiff.jacobian(f, similar(x), x) * v

@test num_hesvec!(dy, g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test num_hesvec!(dy, g, x, v, similar(v), similar(v),
                  similar(v))≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test num_hesvec(g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2

@test numauto_hesvec!(dy, g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test numauto_hesvec!(dy, g, x, v, ForwardDiff.GradientConfig(g, x), similar(v),
                      similar(v))≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test numauto_hesvec(g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8

@test autonum_hesvec!(dy, g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test autonum_hesvec!(dy, g, x, v, cache1, cache2)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test autonum_hesvec(g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8

@test numback_hesvec!(dy, g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test numback_hesvec!(dy, g, x, v, similar(v), similar(v))≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test numback_hesvec(g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8

cache3 = ForwardDiff.Dual{typeof(ForwardDiff.Tag(Nothing, eltype(x))), eltype(x), 1
                          }.(x, ForwardDiff.Partials.(Tuple.(v)))
cache4 = ForwardDiff.Dual{typeof(ForwardDiff.Tag(Nothing, eltype(x))), eltype(x), 1
                          }.(x, ForwardDiff.Partials.(Tuple.(v)))
@test autoback_hesvec!(dy, g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test autoback_hesvec!(dy, g, x, v, cache3, cache4)≈ForwardDiff.hessian(g, x) * v rtol=1e-8
@test autoback_hesvec(g, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-8

@test num_hesvecgrad!(dy, h, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test num_hesvecgrad!(dy, h, x, v, similar(v), similar(v))≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test num_hesvecgrad(h, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2

@test auto_hesvecgrad!(dy, h, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test auto_hesvecgrad!(dy, h, x, v, cache1, cache2)≈ForwardDiff.hessian(g, x) * v rtol=1e-2
@test auto_hesvecgrad(h, x, v)≈ForwardDiff.hessian(g, x) * v rtol=1e-2

@info "JacVec"

L = JacVec(f, x)
@test L * x ≈ auto_jacvec(f, x, x)
@test L * v ≈ auto_jacvec(f, x, v)
@test mul!(dy, L, v) ≈ auto_jacvec(f, x, v)
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*auto_jacvec(f,x,v) + b*_dy
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v) ≈ auto_jacvec(f, v, v)
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*auto_jacvec(f,x,v) + b*_dy

L = JacVec(f, x, autodiff = false)
@test L * x ≈ num_jacvec(f, x, x)
@test L * v ≈ num_jacvec(f, x, v)
@test mul!(dy, L, v)≈num_jacvec(f, x, v) rtol=1e-6
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*num_jacvec(f,x,v) + b*_dy rtol=1e-6
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v)≈num_jacvec(f, v, v) rtol=1e-6
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*num_jacvec(f,x,v) + b*_dy rtol=1e-6

out = similar(v)
gmres!(out, L, v)

@info "HesVec"

x = rand(N)
v = rand(N)
L = HesVec(g, x, autodiff = false)
@test L * x ≈ num_hesvec(g, x, x)
@test L * v ≈ num_hesvec(g, x, v)
@test mul!(dy, L, v)≈num_hesvec(g, x, v) rtol=1e-2
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*num_hesvec(g,x,v) + b*_dy rtol=1e-2
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v)≈num_hesvec(g, v, v) rtol=1e-2
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b) ≈ a*num_hesvec(g,x,v) + b*_dy rtol=1e-2

L = HesVec(g, x)
@test L * x ≈ numauto_hesvec(g, x, x)
@test L * v ≈ numauto_hesvec(g, x, v)
@test mul!(dy, L, v)≈numauto_hesvec(g, x, v) rtol=1e-8
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*numauto_hesvec(g,x,v)+b*_dy rtol=1e-8
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v)≈numauto_hesvec(g, v, v) rtol=1e-8
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*numauto_hesvec(g,x,v)+b*_dy rtol=1e-8

out = similar(v)
gmres!(out, L, v)

@info "HesVecGrad"

x = rand(N)
v = rand(N)
L = HesVecGrad(h, x, autodiff = false)
@test L * x ≈ num_hesvec(g, x, x)
@test L * v ≈ num_hesvec(g, x, v)
@test mul!(dy, L, v)≈num_hesvec(g, x, v) rtol=1e-2
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*num_hesvec(g,x,v)+b*_dy rtol=1e-2
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v)≈num_hesvec(g, v, v) rtol=1e-2
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*num_hesvec(g,x,v)+b*_dy rtol=1e-2

L = HesVecGrad(h, x, autodiff = true)
@test L * x ≈ autonum_hesvec(g, x, x)
@test L * v ≈ numauto_hesvec(g, x, v)
@test mul!(dy, L, v)≈numauto_hesvec(g, x, v) rtol=1e-8
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*numauto_hesvec(g,x,v)+b*_dy rtol=1e-8
update_coefficients!(L, v, nothing, 0.0)
@test mul!(dy, L, v)≈numauto_hesvec(g, v, v) rtol=1e-8
dy=rand(N);_dy=copy(dy);@test mul!(dy,L,v,a,b)≈a*numauto_hesvec(g,x,v)+b*_dy rtol=1e-8

out = similar(v)
gmres!(out, L, v)
#
