include("main.jl")
using .JCC

using Test
text = "int main()\n{\n    return 42;\n}"
toks = tokenize(text)

@testset "tokenizer" begin
    @test toks == [
        TokenId("int"), TokenId("main"), TokenPunct("("), TokenPunct(")"),
        TokenPunct("{"),
        TokenKw("return"), TokenNum(42), TokenPunct(";"),
        TokenPunct("}")
    ]
end

@testset "compile assembly for return 42" begin
    r = makereader(toks)
    def = parseFunDef(r)

    # dump assembly to a file
    open("test.s", "w") do f
        withio(f) do
            compileprelude()
            compile(def)
        end
    end

    # compile it with as and ld
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
end
