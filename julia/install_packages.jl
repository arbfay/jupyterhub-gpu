using Pkg

function main(args)
    exit_code = 0

    if length(args) == 0
        println("Please provide a requirement file")
        return 1
    end

    try
        open(args[1]) do file
            packages = readlines(file)
            Pkg.add(packages)
            for package in packages
                Pkg.build(package)
            end
        end
    catch e
        println(e)
        return 1
    end

    return 0
end

main(ARGS)
