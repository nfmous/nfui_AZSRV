-- Display-only abbreviations: preserve the final word and initial every preceding word.
function nfUI_AbbreviateName(name)
    if type(name)~="string" then return "" end
    local words={}
    for word in string.gfind(name,"%S+") do table.insert(words,word) end
    local count=table.getn(words)
    if count<2 then return words[1] or "" end
    for index=1,count-1 do
        local word=words[index];local byte=string.byte(word,1)
        -- Keep UTF-8 initials intact; byte slicing alone breaks accented names.
        local length=byte>=240 and 4 or byte>=224 and 3 or byte>=192 and 2 or 1
        words[index]=string.sub(word,1,length).."."
    end
    return table.concat(words," ")
end
