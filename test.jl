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

r = makereader(toks)
def = parseFunDef(r)

compile(def)
