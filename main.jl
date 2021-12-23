# open file

function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

@enum TokenType tokenNum tokenId tokenPunct tokenKw

struct Token
    type :: TokenType
    str :: String
end

function tokenize(text)
    tokens = Token[]
    i = 1
    while i <= length(text)
        # skip whitespaces
        if isspace(text[i]) i += 1; continue end

        if isdigit(text[i]) # start parsing a numeral
            token = string(text[i])
            i += 1
            while i <= length(text) && isdigit(text[i])
                token *= text[i]
                i += 1
            end
            push!(tokens, Token(tokenNum, token))
            # TODO put other punctuators
        elseif text[i] in "[](){}.;" # see punctuators A.1.7 
            push!(tokens, Token(tokenPunct, string(text[i])))
            i += 1
        elseif isnondigit(text[i])
            token = string(text[i])
            i += 1 # 1st char cannot be a digit, but the others yes
            while i <= length(text) && (isnondigit(text[i]) || isdigit(text[i]))
                token *= text[i]
                i += 1
            end

            # discriminate between identifiers and keywords
            type = iskeyword(token) ? tokenKw : tokenId
            push!(tokens, Token(type, token))
        else
            error("unhandled character $(text[i])")
        end
    end
    tokens
end

"as defined in the standard, A.1.3"
function isnondigit(c)
    c == '_' || isletter(c)
end

function iskeyword(str)
    # TODO put all A.1.2
    str in ["return"]
end
