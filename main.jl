# open file

function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

struct TokenNum
    n :: Int
end

struct TokenId
    str :: String
end

struct TokenPunct
    str :: String
end

struct TokenKw
    str :: String
end

const Token = Union{TokenNum, TokenId, TokenPunct, TokenKw}

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
            push!(tokens, TokenNum(parse(Int, token)))
            # TODO put other punctuators
        elseif text[i] in "[](){}.;" # see punctuators A.1.7 
            push!(tokens, TokenPunct(string(text[i])))
            i += 1
        elseif isnondigit(text[i])
            token = string(text[i])
            i += 1 # 1st char cannot be a digit, but the others yes
            while i <= length(text) && (isnondigit(text[i]) || isdigit(text[i]))
                token *= text[i]
                i += 1
            end

            # discriminate between identifiers and keywords
            push!(tokens, iskeyword(token) ? TokenKw(token) : TokenId(token))
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
