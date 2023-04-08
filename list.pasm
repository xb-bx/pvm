module List
type List
    objects $any
    count i64
    capacity i64
end

fn newList(capacity i64) *List
    locals
        l List
        list *List
    end
    pushlocal l
    box
    setlocal list

    pushlocal capacity
    pushlocal list
    setfield List:capacity
    
    pushlocal capacity
    newobj $any
    pushlocal list
    setfield List:objects

    pushlocal list
    ret
end
fn ListAppend(list *List obj any) void 
    pushlocal list
    getfield List:capacity
    pushlocal list
    getfield List:count

    eq
    not jtrue notToGrow
    pushlocal list
    call ListGrow
    :notToGrow

    pushlocal obj
    pushlocal list
    getfield List:objects
    pushlocal list
    getfield List:count
    setindex 

    pushlocal list
    getfield List:count
    pushi64 1
    add
    pushlocal list
    setfield List:count
    ret    
end
fn ListGrow(list *List) void
    locals
        newCapacity i64
        newObjects $any
        i i64
    end
    pushlocal list
    getfield List:capacity
    pushlocal list
    getfield List:capacity
    add
    setlocal newCapacity

    pushlocal newCapacity
    newobj $any
    setlocal newObjects
    
    jmp cond
    :body
        pushlocal list
        getfield List:objects
        pushlocal i
        getindex

        pushlocal newObjects
        pushlocal i
        setindex

        pushlocal i
        pushi64 1
        add
        setlocal i
    :cond
        pushlocal list
        getfield List:capacity
        pushlocal i
        lt
        jtrue body
    
    pushlocal newObjects
    pushlocal list
    setfield List:objects

    pushlocal newCapacity
    pushlocal list
    setfield List:capacity

    ret
end
