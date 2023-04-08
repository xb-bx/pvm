module math

fn abs(v i64) i64
    pushi64 0
    pushlocal v
    lt
    jtrue negative
    pushlocal v
    ret
    :negative
    pushlocal v
    neg
    ret
end
fn sign(v i64) i64 
    pushlocal v
    pushi64 0
    eq
    jtrue zero
        pushlocal v
        call abs
        pushlocal v
        div 
        ret
    :zero
        pushi64 0
        ret
end
