package pvm
import "core:log"
import "core:fmt"
import "core:os"
import "core:sys/unix"
import "core:bufio"
import "core:io"
import "core:strconv"
import "core:mem"
import "core:runtime"
import "core:sys/windows"
import "core:time"
import "x86asm"
import "core:math/rand"
import "core:strings"
import "core:unicode/utf16"
import "core:c"
import "core:path/filepath"

when ODIN_OS == .Windows do foreign import econio "econio.lib"
when ODIN_OS == .Linux do foreign import econio "econio.a"

@(link_prefix="econio_")
foreign {
    rawmode :: proc() ---
    normalmode :: proc() ---
    kbhit :: proc() -> bool ---
    getch :: proc() -> c.int ---
}


type_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    if t, ok := arg.(Type); ok {
        switch type in t {
            case PrimitiveType:
                fmt.fmt_value(fi, type, 'v')
            case BoxedType:
                fmt.fmt_value(fi, type.underlaying^, 'v')
                io.write_rune(fi.writer, '*')
            case ArrayType:
                fmt.fmt_value(fi, type.underlaying^, 'v')
                io.write_string(fi.writer, "[]")
            case RefType:
                fmt.fmt_value(fi, type.underlaying^, 'v')
                io.write_string(fi.writer, "&")
            case CustomType:
                io.write_string(fi.writer, type.name)
        }
    }
    return true
}
proper_hex_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    if b, ok := arg.(u8); ok {
        if verb == 'H' { 
            upper := (b & 0xF0) >> 4
            if upper < 10 {
                io.write_rune(fi.writer, cast(rune)(cast(u8)'0' + upper))
            }
            else {
                io.write_rune(fi.writer, cast(rune)(cast(u8)'A' + (upper - 10)))
            }
            lower := (b & 0x0F)
            if lower < 10 {
                io.write_rune(fi.writer, cast(rune)(cast(u8)'0' + lower))
            }
            else {
                io.write_rune(fi.writer, cast(rune)(cast(u8)'A' + (lower - 10)))
            }
        }
        else {
            fmt.fmt_int(fi, u64(b), false,  8, verb)
        }
    }
    else { 
        fmt.fmt_value(fi, arg, verb)
    }
    return true
}
set_formatter :: proc() {
    fmts := new_clone(make(map[typeid]fmt.User_Formatter))
    fmt.set_user_formatters(fmts)
    err := fmt.register_user_formatter(u8, proper_hex_formatter)
    err = fmt.register_user_formatter(Type, type_formatter)
}
print_bytes :: proc(bytes: [dynamic]u8, prefix: bool = false) {
    for b in bytes {
        if prefix {
            fmt.print("0x")
        }
        fmt.printf("%H, ", b)
    }
    fmt.println()
}
BigStruct :: struct {
    one: u64,
    two: u64,
    three: u64,
}
initbig :: proc() -> BigStruct {
    return BigStruct {
        one = 10,
        two = 69,
        three = 420,
    }
}
ctx: runtime.Context = {}
printi64 :: proc "c" (arg: i64) {
    context = ctx
    fmt.println(arg)
}
printbuf: strings.Builder = strings.builder_make_len(128)
printc :: proc "c" (arg: i64) {
    context = ctx
    strings.write_rune(&printbuf, cast(rune)(arg & 0xffff))
}
flush :: proc "c" () {
    context = ctx
    fmt.println(strings.to_string(printbuf))
    strings.builder_reset(&printbuf)
}

main :: proc() {
    using x86asm
    rawmode()
    tracking := mem.Tracking_Allocator {};
    mem.tracking_allocator_init(&tracking, context.allocator);
    context.allocator = mem.tracking_allocator(&tracking);
    ctx = context
    set_formatter()
    before := len(tracking.allocation_map)
    vm := initvm()
    vmm = &vm
    mod, err := load_module(&vm, os.args[1])
    if _, ok := err.(None); !ok {
        fmt.println(err)
        os.exit(1)
    }
    jiterr := jit(&vm)
    if jiterr != nil {
        fmt.println("Err = ", jiterr)
        return
    }
    mainFunction: ^Function = nil
    print: ^Function = nil
    printchar: ^Function = nil
    clearscreen: ^Function = nil
    sleepfn : ^Function = nil
    inspectfn: ^Function = nil
    getkeystatefn: ^Function = nil
    randfn: ^Function = nil
    flushfn: ^Function = nil
    printlnfn: ^Function = nil
    gcmem: ^Function = nil
    kbhitf: ^Function = nil
    getchf: ^Function = nil
    for fn in mod.functions {
        if fn.name == "main" {
            mainFunction = fn
        }
    }
    if _, ok := vm.modules["builtins"]; ok {
        for fn in vm.modules["builtins"].functions {
            if fn.name == "printi64" {
                print = fn
            }
            if fn.name == "gcmem" {
                gcmem = fn
            }
            if fn.name == "println" {
                printlnfn = fn
            }
            if fn.name == "printchar" {
                printchar = fn
            }
            if fn.name == "clear" {
                clearscreen = fn
            }
            if fn.name == "sleep" {
                sleepfn = fn
            }
            if fn.name == "inspect" {
                inspectfn = fn
            }
            if fn.name == "getkeystate" {
                getkeystatefn = fn
            }
            if fn.name == "rand" {
                randfn = fn
            }
            if fn.name == "flush" {
                flushfn = fn
            }
            if fn.name == "kbhit" {
                tasm := initasm()
                kbh := kbhit
                fnaddr := transmute(u64)(&kbh)
                mov(&tasm, Reg64.Rax, fnaddr)
                jmp_reg(&tasm, Reg64.Rax)
                for b, i in tasm.bytes {
                    fn.jmp_body.base[i] = b
                }
            }
            if fn.name == "getch" {
                tasm := initasm()
                kbh := getch
                fnaddr := transmute(u64)(&kbh)
                mov(&tasm, Reg64.Rax, fnaddr)
                jmp_reg(&tasm, Reg64.Rax)
                for b, i in tasm.bytes {
                    fn.jmp_body.base[i] = b
                }
            }
        }
    }
    if print != nil {
        tasm := initasm()
        fn := printi64
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            print.jmp_body.base[i] = b
        }
    }
    if gcmem != nil {
        tasm := initasm()
        fn := gc_mem 
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            gcmem.jmp_body.base[i] = b
        }
    }
    if printlnfn != nil {
        tasm := initasm()
        fn := println
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            printlnfn.jmp_body.base[i] = b
        }
    }
    if printchar != nil {
        tasm := initasm()
        fn := printc
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            printchar.jmp_body.base[i] = b
        }
    }
    if clearscreen != nil {
        tasm := initasm()
        fn := clear
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            clearscreen.jmp_body.base[i] = b
        }
    }
    if sleepfn != nil {
        tasm := initasm()
        fn := sleep
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            sleepfn.jmp_body.base[i] = b
        }
    }
    if inspectfn != nil {
        tasm := initasm()
        fn := inspect
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            inspectfn.jmp_body.base[i] = b
        }
    }
    if getkeystatefn != nil {
        tasm := initasm()
        fn := getkeystate 
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            getkeystatefn.jmp_body.base[i] = b
        }
    }
    if randfn != nil {
        tasm := initasm()
        fn := random 
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            randfn.jmp_body.base[i] = b
        }
    }
    if flushfn != nil {
        tasm := initasm()
        fn := flush
        fnaddr := transmute(u64)(&fn)
        mov(&tasm, Reg64.Rax, fnaddr)
        jmp_reg(&tasm, Reg64.Rax)
        for b, i in tasm.bytes {
            flushfn.jmp_body.base[i] = b
        }
    }
    
    when os.OS == runtime.Odin_OS_Type.Windows {
        handle := windows.GetStdHandle(windows.STD_OUTPUT_HANDLE)
        mode: u32 = 0
        windows.GetConsoleMode(handle, &mode) 
        windows.SetConsoleMode(handle, mode | windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    }
    fnptr := cast(proc "c" () -> i64)cast(rawptr)mainFunction.jitted_body.base
    fmt.println("RUN", fnptr)
    fnptr()
}
random :: proc "c" (min: i64, max: i64) -> i64 {
    context = ctx
    res := min + (rand.int63() % (max - min))
    return res
}
getkeystate :: proc "c" (key: i64) -> i64 {
    context = ctx
    when os.OS == runtime.Odin_OS_Type.Linux {
        panic("NOT IMPLEMENTED")
    }
    else {
        return cast(i64)windows.GetAsyncKeyState(cast(i32)key)
    }
    return 0
}
println :: proc "c" (str: ^StringObject) {
    context = ctx
    s := strings.string_from_ptr(transmute(^byte)(transmute(int)str + size_of(StringObject)), cast(int)str.length * 2)
    fmt.println(s)
 
//     windows.WriteConsoleW(windows.GetStdHandle(windows.STD_OUTPUT_HANDLE), transmute(^u16)(transmute(u64)str + size_of(ObjectHeader) + 8), cast(u32)str.length, nil, nil)
}
vmm: ^VM = nil
gc_mem :: proc "c" () -> int {
    context = ctx
    return gc_stat_free_mem(&vmm.gc)
}
inspect :: proc "c" (obj: ^ObjectHeader) {
    context = ctx
    if !type_is(ArrayType, obj.type) {
        return
    }
    fmt.println(obj.type)
    arr := cast(^ArrayHeader)obj
    ptr := cast([^]i8)transmute(rawptr)(transmute(int)arr + size_of(ArrayHeader))
    for i in 0..<arr.length {
        fmt.println(ptr[i+2])
    }
    fmt.println("Length = ", arr.length)

}
sleep :: proc(ms: u32) {
    time.sleep(time.Duration(cast(i64)ms) * time.Millisecond)
}
clear :: proc() {
    fmt.print("\x1b[2J") 
    fmt.print("\x1b[0;0H")
}
discard :: proc($T: typeid, res: T, b: bool) -> T {
    return res
}
