module JCC

# open file
function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

module Tokens
include("token.jl")
end

# Contains only the definitions of the grammar, not the parsing
# function themselves
module AST
include("ast.jl")
end

module Parse
include("parse.jl")
end

module Compile
include("compile.jl")
end

using .Tokens
using .AST
using .Parse
using .Compile

# emit assembly

# all functions for code generation will have the form `compile(t)`,
# and use a global state to control the output stream


end # module JCC
