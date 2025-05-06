#!/usr/bin/env julia
using JSON
using FilePathsBase: dirname  # for cross‑platform dirname
# Bring in your core optimizer
include(joinpath(@__DIR__, "functions/function_compiler.jl"))

#Load scenario config.json
cfg = JSON.parsefile("config.json")
island   = cfg["island"]
year     = cfg["year"]
scenario = cfg["scenario"]
clean    = cfg["clean"]

#basic model parameters
mipgap        = 0.01
CO2_constraint = false
CO2_limit      = 0.0
RE_constraint  = false
RE_limit       = 0.0

#scenario config
if scenario == "base"
    Grid = false; Captive = false; ImportPrice = 59; NoCoal = false
elseif scenario == "gridcaptive"
    Grid = true;  Captive = true;  ImportPrice = 59; NoCoal = false
elseif scenario == "grid"
    Grid = true;  Captive = false; ImportPrice = 59; NoCoal = false
elseif scenario == "captive"
    Grid = false; Captive = true;  ImportPrice = 59; NoCoal = false
elseif scenario == "highimportprice"
    Grid = false; Captive = false; ImportPrice = 59*1.21; NoCoal = false
elseif scenario == "nocoal"
    Grid = true; Captive = true; ImportPrice = 59; NoCoal = true
else
    error("Unknown scenario: $scenario")
end

#clean constraint config
if clean == "reference"
    CO2_constraint = false
    RE_constraint  = false
elseif clean == "clean"
    CO2_constraint = true
    RE_constraint  = true
else
    error("Unknown clean flag: $clean")
end

#Build paths
base_dir      = dirname(@__FILE__)
inputs_path   = joinpath(base_dir, "data", island, year)
results_root  = joinpath(base_dir, "results")
mkpath(results_root)

job_name     = "$(scenario)_$(island)_$(year)_$(clean)"
results_dir  = joinpath(results_root, job_name)
mkpath(results_dir)

#Call the function compiler
function_compiler(
    inputs_path,
    results_file,
    mipgap,
    CO2_constraint,
    CO2_limit,
    RE_constraint,
    RE_limit,
    Grid,
    Captive,
    ImportPrice,
    NoCoal
)
