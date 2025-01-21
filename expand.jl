
struct Command
    name::String
    value::String
    args::Int
end

struct Def
    name::String
    value::String
end

struct Group{T <: AbstractString, S <: AbstractString}
    content::T
    open_index::Int
    close_index::Int
    text::S
end

function get_group(text::AbstractString, start_ind::Int,
                   open::AbstractString, close::AbstractString)
    if isempty(open) || isempty(close)
        error("Open and close must be non-empty strings")
    end
    n = length(text)
    no = length(open)
    nc = length(close)
    @assert text[start_ind:(start_ind+no-1)] == open
    level = 0
    for i in start_ind:n
        if text[i:(i+no-1)] == open
            level += 1
        elseif text[i:(i+nc-1)] == close
            level -= 1
            if level < 0
                error("Unbalanced brackets")
            end
            if level == 0
                return Group(text[(start_ind+no):(i-1)], start_ind, i+nc-1, text)
            end
        end
    end
    error("No closing string found")
end

function get_group(text::AbstractString, start_ind::Int,
                   open::Char, close::Char)

    @assert text[start_ind] == open
    level = 0
    n = length(text)
    for i in start_ind:n
        if text[i] == open
            level += 1
        elseif text[i] == close
            level -= 1
            if level == 0
                return Group(text, start_ind, i, text[(start_ind+1):(i-1)])
            end
        end
    end
    error("No closing bracket found")
end




function find_next_group(text::AbstractString, start_ind::Int;
                         open::Union{Char, <:AbstractString} = '{',
                         close::Union{Char, <:AbstractString} = '}')
    ind = findnext(open, text, start_ind)
    if isnothing(ind)
        return nothing
    end
    get_group(text, ind[1], open, close)
end



function is_command(line::AbstractString)
    return startswith(line, "\\newcommand")
end

function is_def(line::AbstractString)
    return startswith(line, "\\def")
end

function parse_command(line::AbstractString)
    # section = 0
    # level = 0
    # starts = [0, 0, 0]
    # finishes = [0, 0, 0]

    name = find_next_group(line, 1, open = '{', close = '}')
    args = find_next_group(line, name.close_index + 1, open = '[', close = ']')
    next_ind = isnothing(args) ? name.close_index + 1 : args.close_index + 1
    value = find_next_group(line, next_ind, open = '{', close = '}')


    # for (i, char) in enumerate(line)
    #     if char == '{'
    #         if level == 0
    #             section += 1
    #             starts[section] = i
    #         end
    #         level += 1
    #     elseif char == '}'
    #         level -= 1
    #         if level == 0
    #             finishes[section] = i
    #         end
    #     end
    #     if char == '['
    #         if level == 0
    #             section += 1
    #             starts[section] = i
    #         end
    #         level += 1
    #     elseif char == ']'
    #         level -= 1
    #         if level == 0
    #             finishes[section] = i
    #         end
    #     end
    # end

    # @assert level == 0

    # name = line[starts[1]+1:finishes[1]-1]
    # value = line[starts[3]+1:finishes[3]-1]
    # args = line[(starts[2]+1):(finishes[2]-1)]

    # commands = parse(Int, args)
    commands = isnothing(args) ? 0 : parse(Int, args.text)
    return Command(name.text, value.text, commands)
end

function parse_def(line::AbstractString)
    starts = [0, 0]
    finishes = [0, 0]
    slash_count = 0
    level = 0

    for (i, char) in enumerate(line)
        if char == '\\'
            slash_count += 1
            if slash_count == 2
                starts[1] = i
            end
        elseif char == '{'
            if level == 0
                finishes[1] = i - 1
                starts[2] = i
            end
            level += 1

        elseif char == '}'
            level -= 1

            if level == 0
                finishes[2] = i
            end
        end
    end

    @assert level == 0

    name = line[starts[1]:finishes[1]]
    value = line[starts[2]+1:finishes[2]-1]
    return Def(name, value)
end


function does_command_match(command::AbstractString, line::AbstractString, start::Int, stop::Int, n::Int)
    if line[start:stop] == command
        if stop == n
            return true
        end
        if stop < n && (line[stop+1] == '{' || !isletter(line[stop+1]))
            return true
        end
    end
    return false
end

function replace_command(line::String, command::Command; any_replaced = [false])
    n = length(line)
    nc = length(command.name)
    if n < nc
        return line
    end

    p = command.args

    i_start = 1
    i_stop = nc
    while i_stop <= n
        if does_command_match(command.name, line, i_start, i_stop, n)
            any_replaced[1] = true

            new_value = command.value
            for j in 1:p
                @show command
                group = get_group(line, i_stop + 1, '{', '}')
                new_value = replace(new_value, "#$j" => group.text)
                i_stop = group.close_index
            end

            line = line[1:(i_start-1)] * new_value * line[(i_stop + 1):end]
            i_start = i_start + length(new_value)
            i_stop = i_start + nc
            n = length(line)
        end
        i_start += 1
        i_stop += 1
    end
    return line
end

function replace_def(line::String, def::Def; any_replaced = [false])
    n = length(line)
    nd = length(def.name)
    if n < nd
        return line
    end

    i_start = 1
    i_stop = nd
    while i_stop <= n
        if line[i_start:i_stop] == def.name
            if !isletter(line[i_stop+1])
                any_replaced[1] = true
                lpad = isletter(line[i_start-1]) ? " " : ""
                rpad = isletter(line[i_stop+1]) ? " " : ""
                line_start = line[1:(i_start-1)] * lpad * def.value * rpad
                line = line_start * line[i_stop + 1:end]
                i_start = length(line_start) + 1
                i_stop = i_start + nd
                n = length(line)
            end
        end
        i_start += 1
        i_stop += 1
    end
    return line
end

function split_doc(doc::String)
    begin_doc = findfirst("\\begin{document}", doc)
    if begin_doc == nothing
        error("No \\begin{document} found")
    end
    preamble = doc[1:(begin_doc[1]-1)]
    body = doc[begin_doc[1]:end]
    return preamble, body
end

function expand_doc(doc::String; remove_eq::Bool = true,
                    other_replacements::AbstractVector{
                        <:Pair{<:AbstractString, <:AbstractString}
                    } = ["\\\\" => "@@"])
    if isfile(doc)
        doc = read(doc, String)
    end

    # remove comments
    doc = replace(doc, r"%.*\n" => "")

    preamble, body = split_doc(doc)
    body = convert_beginend(body)
    lines = split(preamble, '\n')
    commands = [parse_command(line) for line in lines if is_command(line)]
    defs = [parse_def(line) for line in lines if is_def(line)]
    any_replaced = [true]
    while any_replaced[1] == true
        any_replaced[1] = false
        for def in defs
            body = replace_def(body, def, any_replaced = any_replaced)
        end
        for command in commands
            body = replace_command(body, command, any_replaced = any_replaced)
        end
    end

    # while any_replaced[1] == true
    #     any_replaced[1] = false
    #     for command in commands
    #         body = replace_command(body, command, any_replaced = any_replaced)
    #     end
    # end

    if remove_eq
        body = remove_eq_lines(body)
    end

    for (old, new) in other_replacements
        body = replace(body, old => new)
    end

    return preamble * body

end

function convert_beginend(text::AbstractString;
                          exclude::Vector{<:AbstractString} = ["document",
                                                               "equation",
                                                               "equation*"],
                          translate::Dict{<:AbstractString, <:AbstractString} =
                                Dict("aligned" => "eqarray"),
                          new_lines = Dict("matrix" => "@@",
                                           "aligned" => "@"))

    regex = r"\\begin{(.+)}"
    matches = [match[1] for match in eachmatch(regex, text)]
    matches = filter(x -> !(x in exclude), matches)

    for match in matches
        bm = "\\begin{$match}"
        em = "\\end{$match}"

        ind = 1

        while true
            group = find_next_group(text, ind, open = bm, close = em)
            if isnothing(group)
                break
            end

            new_match = haskey(translate, match) ? translate[match] : match
            content = convert_beginend(group.content)
            if haskey(new_lines, match)
                content = replace(content, "\\\\" => new_lines[match])
            end
            text_start = text[1:(group.open_index-1)] * "\\$new_match{" * content * "}"
            text = text_start * text[(group.close_index+1):end]
            ind = length(text_start)
            # error()
        end
        # text = replace(text, "\\begin{$match}" => "\\$new_match{")
        # text = replace(text, "\\end{$match}" => "}")
    end
    return text
end


function remove_eq_lines(doc::AbstractString)
    eq_start = "\\begin{equation}"
    eq_end = "\\end{equation}"
    ind = 1
    while true
        group = find_next_group(doc, ind, open = eq_start, close = eq_end)
        @show group
        if isnothing(group)
            break
        end
        # content = replace(group.content, "\n" => " ")
        content = join(split(group.content), ' ')
        doc = doc[1:(group.open_index-1)] * eq_start * "\n" * content * "\n" * eq_end * doc[(group.close_index+1):end]
        ind = group.open_index + length(content)
    end
    return doc
end



function expand_doc(doc::String, out::String)
    expanded = expand_doc(doc)
    write(out, expanded)
    return nothing
end

# expand_doc("county_aggregation.tex", "expanded.tex")
