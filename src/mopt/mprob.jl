#'.. py:class:: MProb
#'
#'   the type MProb describes the optimization
#'   problem, it knows about the parameters
#'   to estimate, their names and bounds, 
#'   but also about the moments and their names.
type MProb

  # setup
  initial_value    :: Dict  # initial parameter value as a dict
  # params_to_sample :: Dict{ASCIIString,Array{Float64,1}}  # a dictionary of upper and lower bound for params we estimate (others are fixed)
  params_to_sample_df  :: DataFrame
  p2sample_sym     :: Array{Symbol,1} # column names of params to sample for dataframes
  objfunc          :: Function # objective function
  objfunc_opts     :: Dict     # options passed to the objective function, e.g. printlevel
  # moments          :: Dict  # a dictionary of moments to track
  moments          :: DataFrame # a dictionary of moments to track
  moments_subset   :: Array{ASCIIString}  # an array of moment names to subset objective funciton

  # constructor
  function MProb(
    initial_value,
    params_to_sample,
    objfunc,moments; 
    moments_subset=moments[:moment],objfunc_opts=Dict())

    this = new()

    # assert that moments has two entries for each moment: value and sd
    # @assert all(map(x -> length(x),values(moments)) .== 2)

    # assert that params_to_sample are subset of initial_value
    @assert issubset(keys(params_to_sample),keys(initial_value))

    # assert that params_to_sample has valid bounds: a vector with 2 increasing entries
    @assert all(map(x -> x[2]-x[1],values(params_to_sample)) .> 0)

    par2sample_name   = sort(collect(keys(params_to_sample)))
    par2sample_sym    = Symbol[x for x in par2sample_name]
    p0 = deepcopy(initial_value)

    pdf = DataFrame(param=collect(keys(params_to_sample)),lb=map(x -> x[1], values(params_to_sample)),ub=map(x -> x[2], values(params_to_sample)))
    sort!(pdf,cols=1)

    this.initial_value       = p0
    this.params_to_sample_df = pdf
    this.p2sample_sym        = par2sample_sym
    this.objfunc             = objfunc
    this.objfunc_opts        = objfunc_opts
    this.moments             = moments
    this.moments_subset      = moments_subset

    return(this)

  end # constructor

  # very simple constructor
  function MProb()
    this = new()
    this.initial_value       = Dict()
    this.params_to_sample_df = DataFrame()
    this.p2sample_sym        = []
    this.objfunc             = x -> x
    this.objfunc_opts        = Dict()
    this.moments             = DataFrame()
    this.moments_subset      = []
    return(this)
  end

end #type

function addParam!(m::MProb,name::ASCIIString,init)
  m.initial_value[symbol(name)] = init
  return m 
end

function addSampledParam!(m::MProb,name::ASCIIString,init,lb,ub)
  m.initial_value[name] = init
  m.params_to_sample_df = rbind(m.params_to_sample_df,DataFrame(param=name,lb=lb,ub=ub))
  return m
end


#'.. py:function:: ps_names
#'
#'   returns the list of paramaters to sample
function ps_names(mprob::MProb)
  return(keys(mprob.initial_value))
end
function ps2s_names(mprob::MProb)
  return(mprob.p2sample_sym)
end

function ms_names(mprob::MProb)
  return(mprob.moments[:moment])
end

function show(io::IO,m::MProb)


  print(io,"MProb Object:\n")
  print(io,"==============\n\n")
  print(io,"Parameters to sample:\n")
  print(io,m.params_to_sample_df)
  print(io,"\nMoment Table:\n")
  print(io,m.moments)
  print(io,"Moment to use:\n")
  print(io,m.moments_subset)
  print(io,"\n")
  print(io,"\nobjective function: $(m.objfunc)\n\n")
  # print(io,"\nobjective function call: $(Expr(:call,m.objfunc,m.current_param,m.moments,m.moments_to_use))\n")
  # if !m.prepared
  #   print(io,"\ncall MoptPrepare(m) to setup cluster\n")
  # else 
  #   print(io,"\nNumber of chains: $(m.N)\n")
  # end
  print(io,"\nEND SHOW MProb\n")
  print(io,"===========================\n")
end
