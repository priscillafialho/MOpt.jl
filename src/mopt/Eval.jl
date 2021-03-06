# We introduce two bojects to facilitate the interfacing
# with the objective function: Eval and Opts.

export Eval, start, finish, param, paramd, fill, dataMoment, dataMomentW, setMoment, setValue, readEval, readEvalArray, readEvalArrayRemote

type Eval

	value        :: Float64
	time         :: Float64
	params       :: Dict
	moments      :: Dict
	dataMoments  :: Dict
	dataMomentsW :: Dict
	status       :: Int64
	options      :: Dict

	function Eval()
		this              = new()
		this.value        = -1
		this.time         = time()
		this.status       = -1
		this.dataMoments  = Dict{Symbol,Float64}()
		this.dataMomentsW = Dict{Symbol,Float64}()
		this.params       = Dict{Symbol,Float64}()
		this.moments      = Dict{Symbol,Float64}()
		return this
	end

	function Eval(p::Dict,mom::DataFrame)
		this = new()
		this.value        = -1
		this.time         = time()
		this.status       = -1
		this.dataMoments  = Dict{Symbol,Float64}()
		this.dataMomentsW = Dict{Symbol,Float64}()
		this.params       = Dict{Symbol,Float64}()
		this.moments      = Dict{Symbol,Float64}()

		for (i in 1:nrow(mom))
			kk = symbol(mom[i,:name])
			this.dataMoments[kk]  = mom[i,:value]
			this.dataMomentsW[kk] = mom[i,:weight]
		end

		for (k in keys(p))
			kk = symbol(k)
			this.params[kk] = p[k][1] # we take the first one, in case there are several values per param
		end

		return this
	end

	function Eval(mprob::MProb,p::Dict)
		this              = new()
		this.value        = -1
		this.time         = time()
		this.status       = -1
		this.dataMoments  = Dict{Symbol,Float64}()
		this.dataMomentsW = Dict{Symbol,Float64}()
		this.params       = Dict{Symbol,Float64}()
		this.moments      = Dict{Symbol,Float64}()

		for (kk in keys(mprob.moments) )
			this.dataMoments[kk]  = mprob.moments[kk][:value]
			this.dataMomentsW[kk] = mprob.moments[kk][:weight]
		end

		for (k in keys(p))
			kk = symbol(k)
			this.params[kk] = p[k]
		end

		return this
	end

	function Eval(p::Dict{Symbol,Float64},m::Dict{Symbol,Float64})
		this              = Eval()
		this.value        = -1
		this.time         = time()
		this.status       = -1
		this.dataMoments  = m
		this.dataMomentsW = Dict{Symbol,Float64}()
		this.params       = p
		this.moments      = Dict{Symbol,Float64}()

		return this
	end

end

function start(ev::Eval)
	ev.time = time()
end

function finish(ev::Eval)
	ev.time =  time() - ev.time
end

param(ev::Eval,ll::Array{Symbol,1})    = [ ev.params[i] for i in ll]
param(ev::Eval,ll::Array{Any,1})       = [ ev.params[i] for i in ll]
param(ev::Eval)                        = param(ev,collect(keys(ev.params)))
param(ev::Eval,s::Symbol)              = param(ev,[s])
paramd(ev::Eval)                       = ev.params
dataMoment(ev::Eval,ll::Array{Symbol,1})  = [ ev.dataMoments[i] for i in ll]
dataMoment(ev::Eval)                      = ev.dataMoments
dataMomentW(ev::Eval,ll::Array{Symbol,1}) = [ ev.dataMomentsW[i] for i in ll]
dataMomentW(ev::Eval)                  = dataMoment(ev,keys(ev.dataMomentsW))
dataMoment(ev::Eval,s::Symbol)         = dataMoment(ev,[s])
dataMomentW(ev::Eval,s::Symbol)        = dataMomentW(ev,[s])
zippedMoments(ev::Eval)                = ev.dataMoments

# this allows to fill the values of a given structure
# with the values from ev
function fill(p::Any,ev::Eval)
	for k in keys(ev.params)
		setfield!(p,k,ev.params[k])
	end
end

function setValue(ev::Eval,value::Float64)
	ev.value = value
end

function setMoment(ev::Eval,k::Symbol,value::Float64)
	ev.moments[k] = value
end

function setMoment(ev::Eval,d::Dict)
	for k in keys(d)
		ev.moments[k] = d[k]
	end
end

# this assumes that colum :name has the names as strings
# and that column :value stores the value
function setMoment(ev::Eval,d::DataFrame)
	for i in 1:nrow(d)
		ev.moments[ symbol(d[i,:name]) ] = d[i,:value]
	end
end

function getBest(evs::Array{Eval,1}) 
  best_val = Inf
  best = None
  for ev in evs
  	if (ev.status>0) & (ev.value<best_val)
  		best = ev
  		best_val = ev.value
  	end
  end
  return best
end

function show(io::IO,ev::Eval)
  print(io,"Eval: val:$(ev.value) status:$(ev.status)\n")
end

if !haskey(ENV,"IGNORE_HDF5")

	import Base.write


    function write(ff5::HDF5File, path::ASCIIString, ev::Eval)

    	# saving value time and status
    	HDF5.write(ff5, joinpath(path,"value")  , ev.value )
    	HDF5.write(ff5, joinpath(path,"status") , ev.status )
    	HDF5.write(ff5, joinpath(path,"time")   , ev.time )

		# saving parameters and moments
		HDF5.write(ff5, joinpath(path,"params_keys")    , convert(Array{ASCIIString,1}, [string(k) for k in keys(ev.params)]))
		HDF5.write(ff5, joinpath(path,"params_vals")    , convert(Array{Float64,1}, [v for v in values(ev.params)]))	 	 
		HDF5.write(ff5, joinpath(path,"moments_keys")   , convert(Array{ASCIIString,1}, [string(k) for k in keys(ev.moments)]))	 
		HDF5.write(ff5, joinpath(path,"moments_vals")   , convert(Array{Float64,1}, [v for v in values(ev.moments)]))	 	 
    end

    function write(ff5::HDF5File, path::ASCIIString, evs::Array{Eval,1})

    	ev = evs[1]
    	p_names = convert(Array{ASCIIString,1}, [string(k) for k in keys(ev.params) ])
    	m_names = convert(Array{ASCIIString,1}, [string(k) for k in keys(ev.moments)])
		HDF5.write(ff5, joinpath(path,"params_keys")    , p_names)
		HDF5.write(ff5, joinpath(path,"moments_keys")    , m_names)	 	 

		# build a matrix for parameters
		V = zeros(length(evs),4)
		P = zeros(length(evs),length(p_names))
		M = zeros(length(evs),length(m_names))

		i = 0
		for ev in evs 
			i = i+1

			V[i,1] = ev.value
			V[i,2] = ev.status
			V[i,3] = ev.time

			j = 0
			for (n in p_names)
				j = j+1
				P[i,j] = ev.params[symbol(n)]
			end

			if (ev.status>0)
				j = 0
				for (n in m_names)
					j = j+1
					M[i,j] = ev.moments[symbol(n)]
				end
			end
		end

    	# saving value time and status
    	HDF5.write(ff5, joinpath(path,"values")     , transpose(V) )
    	HDF5.write(ff5, joinpath(path,"parameters") , transpose(P) )
    	HDF5.write(ff5, joinpath(path,"moments")    , transpose(M) )

    end

    function readEvalArray( ff5::HDF5File, path::ASCIIString)

    	# get list of moments
    	p_names = [ symbol(s) for s in HDF5.read(ff5, joinpath(path,"params_keys")) ]
    	m_names = [ symbol(s) for s in HDF5.read(ff5, joinpath(path,"moments_keys")) ]

    	V = transpose(HDF5.read(ff5, joinpath(path,"values")))
    	P = transpose(HDF5.read(ff5, joinpath(path,"parameters")))
    	M = transpose(HDF5.read(ff5, joinpath(path,"moments")))

    	n   = size(P,1)
    	evs = [ Eval() for i in 1:n]

    	for i in 1:n 
    		ev = evs[i]
    		ev.value  = V[i,1] 
    		ev.status = V[i,2] 
    		ev.time   = V[i,3] 

			V[i,1] = ev.value
			V[i,2] = ev.status
			V[i,3] = ev.time

			j = 0
			for (n in p_names)
				j = j+1
				ev.params[p_names[j]] = P[i,j]
			end

			if (ev.status>0)
				j = 0
				for (n in m_names)
					j = j+1
					ev.moments[m_names[j]] = M[i,j]
				end
			end
    	end

    	return(evs)
    end

    function readEvalArrayRemote(remote::ASCIIString, path::ASCIIString)
    	a = tempname()
    	run(`scp $remote $a`)
    	println("saving locally to $a")
    	h5open(a, "r") do ff
			return readEvalArray(ff,path)
		end
    end

    function readEval( ff5::HDF5File, path::ASCIIString)
    	ev = Eval()

    	# saving value time and status
    	ev.value  = HDF5.read(ff5, joinpath(path,"value"))
    	ev.status = HDF5.read(ff5, joinpath(path,"status"))
    	ev.time   = HDF5.read(ff5, joinpath(path,"time"))

		# saving parameters 
    	kk         = HDF5.read(ff5, joinpath(path,"params_keys"))
    	vv         = HDF5.read(ff5, joinpath(path,"params_vals"))
    	ev.params  = Dict( [ symbol(k) for k in kk] , vv)
    	kk         = HDF5.read(ff5, joinpath(path,"moments_keys"))
    	vv         = HDF5.read(ff5, joinpath(path,"moments_vals"))
    	ev.moments = Dict( [ symbol(k) for k in kk] , vv)

    	return(ev)
    end

    function write(ff5::HDF5File, path::ASCIIString, dd::Dict{Symbol,Float64})
		for (k,v) in dd
			HDF5.write(ff5, joinpath(path,string(k)), v)
		end
    end

end




