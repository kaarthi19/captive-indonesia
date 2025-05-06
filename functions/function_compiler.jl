include("input_data.jl")
include("optimizer.jl")
include("result_extraction_function.jl")

function function_compiler(filepath, results_filepath, mipgap, CO2_constraint, CO2_limit, RE_constraint, RE_limit, Grid, Captive, ImportPrice, NoCoal, CO235reduction, BAUCO2emissions)
    inputs = input_data(filepath)
    solution = capacity_expansion(inputs, mipgap, CO2_constraint, CO2_limit, RE_constraint, RE_limit, Grid, Captive, ImportPrice, NoCoal, CO235reduction, BAUCO2emissions)
    results = result_extraction(solution, inputs.demand, inputs, filepath, results_filepath)

    return(
        results = results,
        solution = solution

        )
end