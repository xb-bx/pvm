module builtins

fn gcmem() i64
pushi64 1337
ret
end
fn println(str string) void
ret
end
fn flush() void
ret
end
fn inspect(arg i64) void 
    ret
end
fn printchar(arg char) void 
    ret
end
fn print(arg any) void
    pushlocal arg
    isinstanceof string
    jtrue str
    pushlocal arg
    isinstanceof i64
    jtrue int64

    pushlocal arg
    isinstanceof i32
    jtrue int32
    jmp unknown
    :str
        pushlocal arg
        cast string
        call println
        pushstr "\n"
        call println
        jmp endof
    :int64
        pushlocal arg
        cast *i64
        unbox
        call printi64
        jmp endof
    :int32 
        pushlocal arg
        cast *i32
        unbox
        conv i64
        call printi64
        jmp endof
    :unknown
        pushstr "unknown type\n"
        call println
    :endof
        ret
end

fn printi32(arg i32) void 
    pushlocal arg
    conv i64
    call printi64
    ret
end
fn printi64(arg i64) void 
    ret
end
fn clear() void
    ret
end
fn sleep(ms i32) void 
    ret
end
fn getkeystate (key i64) i64
    pushi64 1337
    ret
end
fn rand(min i64 max i64) i64 
    pushi64 1000
    ret
end
fn boolToI64(b bool) i64 
    pushlocal b
    jtrue t
    pushi64 0
    ret
    :t
    pushi64 1
    ret
end
