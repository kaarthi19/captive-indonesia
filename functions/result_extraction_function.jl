# Record generation capacity and energy results
function result_extraction(solution, demand, inputs, input_path, results_filepath)
    generation = zeros(size(inputs.G,1))
    for i in 1:size(inputs.G,1) 
        generation[i] = sum(value.(solution.GEN)[:,inputs.G[i]].data) 
    end
    ip_generation = zeros(size(inputs.IP_G,1))
    for i in 1:size(inputs.IP_G,1) 
        ip_generation[i] = sum(value.(solution.IP_GEN)[:,inputs.IP_G[i]].data) 
    end
    ip_heat_generation = zeros(size(inputs.IP_UC,1))
    for i in 1:size(inputs.IP_UC,1) 
        ip_heat_generation[i] = sum(value.(solution.IP_GEN_HEAT)[:,inputs.IP_UC[i]].data) 
    end
    
    total_demand = sum(sum.(eachcol(demand)))
     
    peak_demand = maximum(sum(eachcol(demand)))
    MWh_share = generation./total_demand.*100
    cap_share = value.(solution.CAP).data./peak_demand.*100
    
    generator = DataFrame(
        ID = inputs.G, 
        Resource = inputs.generators.Resource[inputs.G],
        Zone = inputs.generators.Zone[inputs.G],
        technology = inputs.generators.technology[inputs.G],
        owner = inputs.generators.owner[inputs.G],
        Total_MW = value.(solution.CAP).data,
        Start_MW = inputs.generators.Existing_Cap_MW[inputs.G],
        Change_in_MW = value.(solution.CAP).data.-inputs.generators.Existing_Cap_MW[inputs.G],
        Percent_MW = cap_share,
        GWh = generation/1000,
        Percent_GWh = MWh_share,
        STOR = inputs.generators.STOR[inputs.G],
        VRE = inputs.generators.VRE[inputs.G],
        THERM = inputs.generators.THERM[inputs.G],
        New_Build = inputs.generators.New_Build[inputs.G],
    )

    ip_generators = DataFrame(
        ID = inputs.IP_G,
        Resource = inputs.ip_generators.Resource[inputs.IP_G],
        Zone = inputs.ip_generators.Zone[inputs.IP_G],
        technology = inputs.ip_generators.technology[inputs.IP_G],
        #owner = inputs.ip_generators.owner[inputs.IP_G],
        Total_MW = value.(solution.IP_CAP).data,
        Start_MW = inputs.ip_generators.Existing_Cap_MW[inputs.IP_G],
        Change_in_MW = value.(solution.IP_CAP).data.-inputs.ip_generators.Existing_Cap_MW[inputs.IP_G],
        Electricity_GWh = ip_generation/1000,
        commodity = inputs.ip_generators.commodity[inputs.IP_G],
        plant_owner = inputs.ip_generators.plant_owner[inputs.IP_G],
        owner_parent_company = inputs.ip_generators.owner_parent_company[inputs.IP_G],
        owner_home_country_flag = inputs.ip_generators.owner_home_country_flag[inputs.IP_G],
        #Percent_GWh = MWh_share,
        #STOR = inputs.ip_generators.STOR[inputs.IP_G],
        #VRE = inputs.ip_generators.VRE[inputs.IP_G],
        #THERM = inputs.ip_generators.THERM[inputs.IP_G],
        #New_Build = inputs.ip_generators.New_Build[inputs.IP_G],
    )
    ip_heat_generators = DataFrame(
        ID = inputs.IP_UC,
        Resource = inputs.ip_generators.Resource[inputs.IP_UC],
        Zone = inputs.ip_generators.Zone[inputs.IP_UC],
        technology = inputs.ip_generators.technology[inputs.IP_UC],
        #owner = inputs.ip_generators.owner[inputs.IP_G],
        GWh = ip_heat_generation/1000
    )

    # Grid import for industrial parks
    if solution.IP_IMPORT == 0 
        ip_import = DataFrame(
            ID = inputs.IP,
            Zone = inputs.ip_generators.Zone[inputs.IP],
            Total_Import_MWh = zeros(length(inputs.IP)),
            Peak_Import_MW = zeros(length(inputs.IP)),
        )
    else
        # Grid import for industrial parks
        ip_import = DataFrame(
            ID = inputs.IP,
            Zone = inputs.ip_generators.Zone[inputs.IP],
            Total_Import_MWh = vec(sum(value.(solution.IP_IMPORT)[:,inputs.IP].data, dims=1)),
            Peak_Import_MW = vec(maximum(value.(solution.IP_IMPORT)[:,inputs.IP].data, dims=1)),
        )
    end
    
    #energy storage energy capacity results (MWh)
    storage = DataFrame(
        ID = inputs.STOR, 
        Zone = inputs.generators.Zone[inputs.STOR],
        Resource = inputs.generators.Resource[inputs.STOR],
        Total_Storage_MWh = value.(solution.E_CAP).data,
        Start_Storage_MWh = inputs.generators.Existing_Cap_MWh[inputs.STOR],
        Change_in_Storage_MWh = value.(solution.E_CAP).data.- inputs.generators.Existing_Cap_MWh[inputs.STOR],
    )
    
    #industrial park storage energy capacity results (MWh)
    ip_storage = DataFrame(
        ID = inputs.IP_STOR, 
        Zone = inputs.ip_generators.Zone[inputs.IP_STOR],
        Resource = inputs.ip_generators.Resource[inputs.IP_STOR],
        Total_Storage_MWh = value.(solution.IP_E_CAP).data,
        Start_Storage_MWh = inputs.ip_generators.Existing_Cap_MWh[inputs.IP_STOR],
        Change_in_Storage_MWh = value.(solution.IP_E_CAP).data.- inputs.ip_generators.Existing_Cap_MWh[inputs.IP_STOR],
    )
    
    # transmission capacity results
    transmission = DataFrame(
        ID = inputs.L, 
        Path = inputs.lines.path_name[inputs.L],
        Substation_Path = inputs.lines.substation_path[inputs.L],
        Total_Transfer_Capacity = value.(solution.T_CAP).data,
        Start_Transfer_Capacity = inputs.lines.Line_Max_Flow_MW,
        Change_in_Transfer_Capacity = value.(solution.T_CAP).data.-inputs.lines.Line_Max_Flow_MW,
    )
    
    # non-served energy results by segment and zone
    num_segments = maximum(inputs.S)
    num_zones = maximum(inputs.Z)
    nse_r = DataFrame(
        Segment = zeros(num_segments*num_zones),
        Zone = zeros(num_segments*num_zones),
        NSE_Price = zeros(num_segments*num_zones),
        Max_NSE_MW = zeros(num_segments*num_zones),
        Total_NSE_MWh = zeros(num_segments*num_zones),
        NSE_Percent_of_Demand = zeros(num_segments*num_zones)
    )
    i=1
    for s in inputs.S
        for z in inputs.Z
            nse_r.Segment[i]=s
            nse_r.Zone[i]=z
            nse_r.NSE_Price[i]=inputs.nse.NSE_Cost[s]
            nse_r.Max_NSE_MW[i]=maximum(value.(solution.NSE)[:,s,z].data)
            nse_r.Total_NSE_MWh[i]=sum(value.(solution.NSE)[:,s,z].data)
            nse_r.NSE_Percent_of_Demand[i]=sum(value.(solution.NSE)[:,s,z].data)/total_demand*100
            i=i+1
        end
    end

    # non-served energy results by segment and zone for industrial parks
    num_segments_ip = maximum(inputs.S)
    num_ip = maximum(inputs.IP)
    nse_r_ip = DataFrame(
        Segment = zeros(num_segments_ip*num_ip),
        Zone = zeros(num_segments_ip*num_ip),
        NSE_Price = zeros(num_segments_ip*num_ip),
        Max_NSE_MW = zeros(num_segments_ip*num_ip),
        Total_NSE_MWh = zeros(num_segments_ip*num_ip),
        NSE_Percent_of_Demand = zeros(num_segments_ip*num_ip)
    )
    i=1
    for s in inputs.S
        for ip in inputs.IP
            nse_r_ip.Segment[i]=s
            nse_r_ip.Zone[i]=ip
            nse_r_ip.NSE_Price[i]=inputs.nse.NSE_Cost[s]
            nse_r_ip.Max_NSE_MW[i]=maximum(value.(solution.IP_NSE)[:,s,ip].data)
            nse_r_ip.Total_NSE_MWh[i]=sum(value.(solution.IP_NSE)[:,s,ip].data)
            nse_r_ip.NSE_Percent_of_Demand[i]=sum(value.(solution.IP_NSE)[:,s,ip].data)/total_demand*100
            i=i+1
        end
    end
    
    #cost_results (recorded in million dollars)
    cost = DataFrame(
        Total_Costs = solution.cost/10^6,
        Fixed_Costs_Generation = value.(solution.FixedCostsGeneration)/10^6,
        #Fixed_Costs_Storage = value.(solution.FixedCostsStorage)/10^6,
        Fixed_Costs_Transmission = value.(solution.FixedCostsTransmission)/10^6,
        Variable_Costs_Grid = value.(solution.VariableCostsGrid)/10^6,
        Variable_Costs_IP = value.(solution.VariableCostsIP)/10^6,
        NSE_Costs = value.(solution.NSECosts)/10^6,
        Grid_Import_Costs = value.(solution.GridImportCosts)/10^6

    )

    clean_energy = DataFrame(
        CO2_Emissions = value.(solution.CO2Emissions),
        CO2_Emissions_Grid = value.(solution.CO2EmissionsGrid),
        CO2_Emissions_IP = value.(solution.CO2EmissionsIP),
        Grid_REShare = value.(solution.REShare)
    )
    
    # Output path 
    out_results = "" 
    outpath = input_path * out_results * results_filepath
    
    # If output directory does not exist, create it
    if !(isdir(outpath))
        mkdir(outpath)
    end
    
    CSV.write(joinpath(outpath, "generator_results.csv"), generator)
    CSV.write(joinpath(outpath, "storage_results.csv"), storage)
    CSV.write(joinpath(outpath, "transmission_results.csv"), transmission)
    CSV.write(joinpath(outpath, "nse_results.csv"), nse_r)
    CSV.write(joinpath(outpath, "cost_results.csv"), cost)
    CSV.write(joinpath(outpath, "clean_energy_results.csv"), clean_energy)
    CSV.write(joinpath(outpath, "ip_generator_results.csv"), ip_generators)
    CSV.write(joinpath(outpath, "ip_import_results.csv"), ip_import)
    CSV.write(joinpath(outpath, "ip_heat_generator_results.csv"), ip_heat_generators)
    CSV.write(joinpath(outpath, "ip_storage_results.csv"), ip_storage)
    CSV.write(joinpath(outpath, "ip_nse_results.csv"), nse_r_ip)
    
    return(
        generator_results = generator,
        storage_results = storage,
        transmission_results = transmission,
        nse_results = nse_r,
        cost_results = cost,
        clean_energy = clean_energy,
        ip_generator_results = ip_generators
    )
end