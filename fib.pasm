module fib
fn printi64(arg i64) void
    ret
end
fn main () i64 
    locals 
        prev i64
        current i64
        next i64
        i i64
        c i64
    end
    pushi64 300
    setlocal c
    pushlocal c
    pushi64 0
    eq
    not
    jtrue notzero
    
    pushi64 0
    ret
    
    :notzero
    
    pushlocal c
    pushi64 1
    eq
    not
    jtrue notone
    pushi64 1
    ret
    
    :notone

    pushi64 1
    setlocal current
    pushi64 0
    setlocal prev
    pushi64 1
    setlocal i

    jmp loopcond
    :loop
        pushlocal current
        pushlocal prev 
        add

        pushlocal current
        setlocal prev
        
        setlocal current 
        pushlocal current
        call printi64

        pushlocal i
        pushi64 1
        add
        setlocal i
    :loopcond
        pushlocal c
        pushlocal i
        lt
        jtrue loop
    pushlocal current
    ret
end
