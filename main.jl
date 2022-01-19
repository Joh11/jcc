module JCC

# open file
function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

module Tokens include("token.jl") end

# Contains only the definitions of the grammar, not the parsing
# function themselves
module AST include("ast.jl") end
module Parse include("parse.jl") end
module Compile include("compile.jl") end

using .Tokens
using .AST
using .Parse
using .Compile

function rpn(d::AST.Decl)
    ret = rpn(d.specs)
    ret *= rpn(d.initds)
    ret *= "decl "
end

function rpn(d::AST.Decltor)
    ret = ""# rpn(d.ptr) TODO
    ret *= rpn(d.direct)
    ret *= "decltor "
end

function rpn(dd::AST.DDParams)
    ret = rpn(dd.dd)
    ret *= rpn(dd.params)
    if dd.ell ret *= "... " end
    ret * "direct-declarator-params "
end

function rpn(f::AST.FunDef)
    ret = rpn(f.specs)
    ret *= rpn(f.decltor)
    # ret *= rpn(f.stmt) TODO
    ret * "fundef "
end

rpn(kw::Tokens.Kw) = "#$(kw.str) "
rpn(kw::Tokens.Id) = "<$(kw.str)> "

function rpn(xs::Vector{T} where T)
    ret = ""
    for x in xs
        ret *= rpn(x)
    end
    ret * "[] "
end

end # module JCC
