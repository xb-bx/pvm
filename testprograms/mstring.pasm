module mstring

fn index_of (str string c char) i64 
    pushi64 0
    ret
end
fn split (str string delimiter char) $string 
    pushnull 
    cast $string
    ret
end
fn array_to_string (arr $char len i64) string 
    pushnull 
    cast string
    ret
end
