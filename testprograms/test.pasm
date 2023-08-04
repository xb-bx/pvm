module test
import builtins
import mstring 
import fn array_to_string from mstring
import fn println from builtins
import fn printchar from builtins
import fn flush from builtins
fn main() void
    locals 
        arr $char
    end
    pushi64 1
    newobj $char
    setlocal arr
    pushchar 'H' 
    pushlocal arr
    pushi64 0
    setindex
    pushi64 1
    pushlocal arr
    pushlocal arr
    pushi64 0
    getindex
    call printchar
    call flush
    call array_to_string
    call println

    ret
end
