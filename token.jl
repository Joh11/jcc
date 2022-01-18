export Token, tokenize

struct Num
    n :: Int
end

struct Id
    str :: String
end

struct Punct
    str :: String
end

struct Kw
    str :: String
end

const Token = Union{Num, Id, Punct, Kw}

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
            push!(tokens, Num(parse(Int, token)))
            # TODO put other punctuators
        elseif text[i] in "[](){}.;" # see punctuators A.1.7 
            push!(tokens, Punct(string(text[i])))
            i += 1
        elseif isnondigit(text[i])
            token = string(text[i])
            i += 1 # 1st char cannot be a digit, but the others yes
            while i <= length(text) && (isnondigit(text[i]) || isdigit(text[i]))
                token *= text[i]
                i += 1
            end

            # discriminate between identifiers and keywords
            push!(tokens, iskeyword(token) ? Kw(token) : Id(token))
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
