using CSV
using DataFrames
import Base.Filesystem: dirname, mkpath

function result_extraction(solution, demand, inputs, input_path, results_filepath)
    # 1) Compute generation aggregates
    generation = zeros(size(inputs.G,1))
    for i in 1:size(inputs.G,1)
        generation[i] = sum(value.(solution.GEN)[:, inputs.G[i]].data)
    end

    ip_generation = zeros(size(inputs.IP_G,1))
    for i in 1:size(inputs.IP_G,1)
        ip_generation[i] = sum(value.(solution.IP_GEN)[:, inputs.IP_G[i]].data)
    end

    ip_heat_generation = zeros(size(inputs.IP_UC,1))
    for i in 1:size(inputs.IP_UC,1)
        ip_heat_generation[i] = sum(value.(solution.IP_GEN_HEAT)[:, inputs.IP_UC[i]].data)
    end

    total_demand = sum(sum.(eachcol(demand)))
    peak_demand  = maximum(sum(eachcol(demand)))
    MWh_share    = generation ./ total_demand .* 100
    cap_share    = value.(solution.CAP).data ./ peak_demand .* 100

    # 2) Build your DataFrames
    generator = DataFrame(
        ID             = inputs.G,
        Resource       = inputs.generators.Resource[inputs.G],
        Zone           = inputs.generators.Zone[inputs.G],
        technology     = inputs.generators.technology[inputs.G],
        owner          = inputs.generators.owner[inputs.G],
        Total_MW       = value.(solution.CAP).data,
        Start_MW       = inputs.generators.Existing_Cap_MW[inputs.G],
        Change_in_MW   = value.(solution.CAP).data .- inputs.generators.Existing_Cap_MW[inputs.G],
        Percent_MW     = cap_share,
        GWh            = generation ./ 1000,
        Percent_GWh    = MWh_share,
        STOR           = inputs.generators.STOR[inputs.G],
        VRE            = inputs.generators.VRE[inputs.G],
        THERM          = inputs.generators.THERM[inputs.G],
        New_Build      = inputs.generators.New_Build[inputs.G],
    )

    ip_generators = DataFrame(
        ID                   = inputs.IP_G,
        Resource             = inputs.ip_generators.Resource[inputs.IP_G],
        Zone                 = inputs.ip_generators.Zone[inputs.IP_G],
        technology           = inputs.ip_generators.technology[inputs.IP_G],
        Total_MW             = value.(solution.IP_CAP).data,
        Start_MW             = inputs.ip_generators.Existing_Cap_MW[inputs.IP_G],
        Change_in_MW         = value.(solution.IP_CAP).data .- inputs.ip_generators.Existing_Cap_MW[inputs.IP_G],
        Electricity_GWh      = ip_generation ./ 1000,
        commodity            = inputs.ip_generators.commodity[inputs.IP_G],
        plant_owner          = inputs.ip_generators.plant_owner[inputs.IP_G],
        owner_parent_company = inputs.ip_generators.owner_parent_company[inputs.IP_G],
        owner_home_country_flag = inputs.ip_generators.owner_home_country_flag[inputs.IP_G],
    )

    ip_heat_generators = DataFrame(
        ID         = inputs.IP_UC,
        Resource   = inputs.ip_generators.Resource[inputs.IP_UC],
        Zone       = inputs.ip_generators.Zone[inputs.IP_UC],
        technology = inputs.ip_generators.technology[inputs.IP_UC],
        GWh        = ip_heat_generation ./ 1000
    )

    # 3) Industrial‐park imports
    if all(value.(solution.IP_IMPORT) .== 0)
        ip_import = DataFrame(
            ID              = inputs.IP,
            Zone            = inputs.ip_generators.Zone[inputs.IP],
            Total_Import_MWh = zeros(length(inputs.IP)),
            Peak_Import_MW  = zeros(length(inputs.IP)),
        )
    else
        ip_import = DataFrame(
            ID               = inputs.IP,
            Zone             = inputs.ip_generators.Zone[inputs.IP],
            Total_Import_MWh = vec(sum(value.(solution.IP_IMPORT)[:, inputs.IP].data, dims=1)),
            Peak_Import_MW   = vec(maximum(value.(solution.IP_IMPORT)[:, inputs.IP].data, dims=1)),
        )
    end

    # 4) Storage
    storage = DataFrame(
        ID                    = inputs.STOR,
        Zone                  = inputs.generators.Zone[inputs.STOR],
        Resource              = inputs.generators.Resource[inputs.STOR],
        Total_Storage_MWh     = value.(solution.E_CAP).data,
        Start_Storage_MWh     = inputs.generators.Existing_Cap_MW[inputs.STOR],
        Change_in_Storage_MWh = value.(solution.E_CAP).data .- inputs.generators.Existing_Cap_MW[inputs.STOR],
    )

    ip_storage = DataFrame(
        ID                    = inputs.IP_STOR,
        Zone                  = inputs.ip_generators.Zone[inputs.IP_STOR],
        Resource              = inputs.ip_generators.Resource[inputs.IP_STOR],
        Total_Storage_MWh     = value.(solution.IP_E_CAP).data,
        Start_Storage_MWh     = inputs.ip_generators.Existing_Cap_MW[inputs.IP_STOR],
        Change_in_Storage_MWh = value.(solution.IP_E_CAP).data .- inputs.ip_generators.Existing_Cap_MW[inputs.IP_STOR],
    )

    # 5) Transmission
    transmission = DataFrame(
        ID                      = inputs.L,
        Path                    = inputs.lines.path_name[inputs.L],
        Substation_Path         = inputs.lines.substation_path[inputs.L],
        Total_Transfer_Capacity = value.(solution.T_CAP).data,
        Start_Transfer_Capacity = inputs.lines.Line_Max_Flow_MW,
        Change_in_Transfer_Capacity = value.(solution.T_CAP).data .- inputs.lines.Line_Max_Flow_MW,
    )

    # 6) Non‐served energy (system and IP)
    total_demand = sum(sum.(eachcol(demand)))
    num_s       = maximum(inputs.S)
    num_z       = maximum(inputs.Z)
    nse_r = DataFrame(
        Segment = Int[], Zone = Int[],
        NSE_Price = Float64[],
        Max_NSE_MW = Float64[], Total_NSE_MWh = Float64[],
        NSE_Percent_of_Demand = Float64[]
    )
    for s in inputs.S, z in inputs.Z
        push!(nse_r, (
            s,
            z,
            inputs.nse.NSE_Cost[s],
            maximum(value.(solution.NSE)[:, s, z].data),
            sum(value.(solution.NSE)[:, s, z].data),
            sum(value.(solution.NSE)[:, s, z].data) / total_demand * 100
        ))
    end

    num_ip = maximum(inputs.IP)
    nse_r_ip = DataFrame(
        Segment = Int[], Zone = Int[],
        NSE_Price = Float64[],
        Max_NSE_MW = Float64[], Total_NSE_MWh = Float64[],
        NSE_Percent_of_Demand = Float64[]
    )
    for s in inputs.S, ip in inputs.IP
        push!(nse_r_ip, (
            s,
            ip,
            inputs.nse.NSE_Cost[s],
            maximum(value.(solution.IP_NSE)[:, s, ip].data),
            sum(value.(solution.IP_NSE)[:, s, ip].data),
            sum(value.(solution.IP_NSE)[:, s, ip].data) / total_demand * 100
        ))
    end

    # 7) Costs & clean energy
    cost = DataFrame(
        Total_Costs               = solution.cost / 1e6,
        Fixed_Costs_Generation    = value.(solution.FixedCostsGeneration) / 1e6,
        Fixed_Costs_Transmission  = value.(solution.FixedCostsTransmission) / 1e6,
        Variable_Costs_Grid       = value.(solution.VariableCostsGrid) / 1e6,
        Variable_Costs_IP         = value.(solution.VariableCostsIP) / 1e6,
        NSE_Costs                 = value.(solution.NSECosts) / 1e6,
        Grid_Import_Costs         = value.(solution.GridImportCosts) / 1e6
    )

    clean_energy = DataFrame(
        CO2_Emissions      = value.(solution.CO2Emissions),
        CO2_Emissions_Grid = value.(solution.CO2EmissionsGrid),
        CO2_Emissions_IP   = value.(solution.CO2EmissionsIP),
        Grid_REShare       = value.(solution.REShare)
    )

    # 8) Prepare output directory
    outdir = dirname(results_filepath)
    mkpath(outdir)

    # 9) Write all CSVs
    CSV.write(joinpath(outdir, "generator_results.csv"), generator)
    CSV.write(joinpath(outdir, "ip_generator_results.csv"), ip_generators)
    CSV.write(joinpath(outdir, "ip_heat_generator_results.csv"), ip_heat_generators)
    CSV.write(joinpath(outdir, "ip_import_results.csv"), ip_import)
    CSV.write(joinpath(outdir, "storage_results.csv"), storage)
    CSV.write(joinpath(outdir, "ip_storage_results.csv"), ip_storage)
    CSV.write(joinpath(outdir, "transmission_results.csv"), transmission)
    CSV.write(joinpath(outdir, "nse_results.csv"), nse_r)
    CSV.write(joinpath(outdir, "ip_nse_results.csv"), nse_r_ip)
    CSV.write(joinpath(outdir, "cost_results.csv"), cost)
    CSV.write(joinpath(outdir, "clean_energy_results.csv"), clean_energy)

    return (
        generator_results      = generator,
        ip_generator_results   = ip_generators,
        ip_heat_generator_results = ip_heat_generators,
        ip_import_results      = ip_import,
        storage_results        = storage,
        ip_storage_results     = ip_storage,
        transmission_results   = transmission,
        nse_results            = nse_r,
        ip_nse_results         = nse_r_ip,
        cost_results           = cost,
        clean_energy           = clean_energy
    )
end
