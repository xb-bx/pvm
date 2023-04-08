module fibrecursive

fn main() i64
    locals
        i i64
    end
    pushi64 0
    setlocal i
    :loop
    pushlocal i
    pushi64 30
    eq 
    jtrue endloop
    pushlocal i 
    call fib
    call printi64
    pushlocal i
    pushi64 1
    add
    setlocal i
    jmp loop
    :endloop
    pushi64 0
    ret
end
fn printi64(arg i64) void
    ret
end
fn fib(arg i64) i64 
    pushlocal arg
    pushi64 0
    eq
    not 
    jtrue notzero

    pushi64 0
    ret

    :notzero
    
    pushlocal arg
    pushi64 1
    eq
    not 
    jtrue notone
    pushi64 1
    ret
    
    :notone
    pushi64 1
    pushlocal arg
    sub
    call fib
    pushi64 2
    pushlocal arg
    sub
    call fib
    add
    ret
end
