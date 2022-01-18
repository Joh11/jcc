include("main.jl")
using .JCC

using Test
text = "int main()\n{\n    return 42;\n}"
toks = JCC.tokenize(text)

@testset "tokenizer" begin
    @test toks == [
        JCC.Tokens.Id("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"), JCC.Tokens.Num(42), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]
end

@testset "compile assembly for return 42" begin
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    # dump assembly to a file
    open("test.s", "w") do f
        JCC.withio(f) do
            JCC.compileprelude()
            JCC.compile(def)
        end
    end

    # compile it with as and ld
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
end
