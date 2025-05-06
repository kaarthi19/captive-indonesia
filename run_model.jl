#!/usr/bin/env julia
using JSON
using JuMP
using Plots
using DataFrames, CSV
using Gurobi

# core model logic
include(joinpath(@__DIR__, "functions/function_compiler.jl"))

# 1) load scenario config
cfg               = JSON.parsefile("config.json")
island            = cfg["island"]
year              = cfg["year"]
scenario          = cfg["scenario"]
clean             = cfg["clean"]
CO235reduction    = cfg["CO235reduction"]
BAUCO2emissions   = cfg["BAUCO2emissions"]
CO2_limit         = cfg["CO2_limit"]

# 2) baseline settings
mipgap         = 0.01
CO2_constraint = false
RE_constraint  = false
RE_limit       = 0.0

# scenario toggles
if scenario == "base"
    Grid = false; Captive = false; ImportPrice = 59;   NoCoal = false
elseif scenario == "gridcaptive"
    Grid = true;  Captive = true;  ImportPrice = 59;   NoCoal = false
elseif scenario == "grid"
    Grid = true;  Captive = false; ImportPrice = 59;   NoCoal = false
elseif scenario == "captive"
    Grid = false; Captive = true;  ImportPrice = 59;   NoCoal = false
elseif scenario == "highimportprice"
    Grid = false; Captive = false; ImportPrice = 59*1.21; NoCoal = false
elseif scenario == "nocoal"
    Grid = false; Captive = false; ImportPrice = 59;     NoCoal = true
else
    error("Unknown scenario: $scenario")
end

# clean‑flag overrides
if clean == "reference"
    CO2_constraint = false
    RE_constraint  = false
elseif clean == "clean"
    CO2_constraint = true
    RE_constraint  = true
end

# 3) paths
base_dir     = @__DIR__
inputs_path  = joinpath(base_dir, "data_indonesia", year, island)
results_root = joinpath(base_dir, "results")
mkpath(results_root)

job_name    = "$(scenario)_$(island)_$(year)_$(clean)"
results_dir = joinpath(results_root, job_name)
mkpath(results_dir)

# 4) run compiler, passing new parameters
function_compiler(
    inputs_path,
    results_dir,
    mipgap,
    CO2_constraint,
    CO2_limit,
    RE_constraint,
    RE_limit,
    Grid,
    Captive,
    ImportPrice,
    NoCoal,
    CO235reduction,
    BAUCO2emissions
)
