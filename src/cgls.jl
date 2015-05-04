export cgls

function cgls{T}(A::SparseMatrixCSC{T,Int64},b::Array{T,1}; kwargs...) 
	x1 = zeros(T,size(A,1))
	x2 = zeros(T,size(A,2))
	
	Alinop = LinearOperator(size(A,1),size(A,2),T,false,false,
							v -> A_mul_B!(1.0,A,v,0.0,x1),nothing,
							v -> At_mul_B!(1.0,A,v,0.0,x2))
	return cgls(Alinop,b;kwargs...)
end

cgls(A::Array,b::Vector;kwargs...) = cgls(LinearOperator(A),b::Vector;kwargs...)



function cgls(A::LinearOperator,b::Vector; tol::Real=1e-2,maxIter::Int=100,x::Vector=[],interm::Int=0,out::Int=0)
# x,flag,err,iter,resvec = cg(A,b,tol=1e-2,maxIter=100,x=[],interm=0,out=0)
#
# CGLS Conjugate gradient algorithm applied implicitly to the normal equations 
# 
# 		(A'*A) x = A'*b.
#
# Input:
#
#	A       - matrix or function computing A*x = A(x,'F') and A'*x = A(x,'T')
#	b       - right hand side vector
#	tol     - error tolerance, default 1e-2
#	maxIter - maximum number of iterations, default 100
#	x       - starting guess
#	interm  - flag for returning intermediate solutions (useful in inverse 
#	out     - flag for output (-1: no output, 0 : only errors, 1 : final status, 2: error at each iteration)
#
# Output:
#
#	x       - approximate solution (interm==0) or history of approximate solutions (interm==1)
#	flag    - exit flag (  0 : desired tolerance achieved,
#	                      -1 : maxIter reached without converging
#	                      -2 : Matrix A is not positive definite )
#	eta     - residual norm: norm(A*x-b)
#	rho     - norm of current iterate: norm(x)
	
	# Initialization.
	if isempty(x)
		r = copy(b)			# residual r = b - A*x
		s = A'*r		# compute gradient g = A'*(A*x-b)
		n = length(s)
		x = zeros(n)
	else
		n = length(x)
		r = b-A*x
		s = A'*r
	end
	
	
	if interm==1
		X = zeros(n,maxIter)	# allocate space for intermediates
	end
	
	p      = copy(s)
	normS0 = BLAS.dot(n,s,1,s,1)       # squared norm of gradients
	normSc = normS0
	eta    = zeros(maxIter) # norm of residuals
	rho    = zeros(maxIter) # norm or current iterate
	
	# Iterate.
	flag = -1
	if out==2
		println("=== cgls ===")
		println(@sprintf("%4s\t%8s\t%8s","iter","norm(r)","norm(x)"))
	end
	
	iter = 1 # makes iter available outside the loop
	for iter=1:maxIter
		q     = A*p # compute A*g
		alpha = normSc/dot(q,q)
		BLAS.axpy!(n,alpha,p,1,x,1) # faster than x    += alpha*p
		
		if interm==1; X[:,iter] = x; end
		
		r-= alpha*q
		# BLAS.axpy!(n,-alpha,q,1,r,1) # faster than r  -= alpha*q
		# println("err2=$(norm(rt-r)/norm(rt))")
		s   = A'*r # compute gradient, that is A'*r
		
		normSt = BLAS.dot(n,s,1,s,1)
		if normSt/normS0 <= tol
		    eta = eta[1:iter-1]
			rho = rho[1:iter-1]
			flag = 0; break
		end
		
		beta = normSt/normSc
		
		BLAS.scal!(n,beta,p,1)
		BLAS.axpy!(n,1.0,s,1,p,1)
		# faster than p   = s + beta*p
		
		# store intermediates and report resuls
		normSc = normSt
		eta[iter] = BLAS.nrm2(n,r,1) # faster than norm(r)
		rho[iter] = BLAS.nrm2(n,x,1) # faster than norm(x)
		if out==2;  println(@sprintf("%3d\t%1.2e\t%1.2e",iter,rho[iter],eta[iter]));end
	end
	
	if out>=0
		if flag==-1
			println(@sprintf("cgls iterated maxIter (=%d) times witout reaching tolerance. Returned result has residual norm  %1.2e.",
																													maxIter,eta[end]))
		elseif out>=1
			println(@sprintf("cgls relative gradient norm below desired tolerance at iteration %d. Returned result has residual norm  %1.2e.",
																													iter,eta[end]))
		end
	end
	
	if interm==1
		return X[:,1:iter],flag,rho,eta
	else
		return x,flag,rho,eta
	end
end
