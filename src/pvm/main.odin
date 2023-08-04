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
import "../vmcore/x86asm"
import "../vmcore"
import "core:math/rand"
import "core:strings"
import "core:unicode/utf16"
import "core:c"
import "core:path/filepath"
import "../modules/mstring"
import "../modules/builtins"



type_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    using vmcore
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
    using vmcore
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

main :: proc() {
    using x86asm
    builtins.rawmode()
    tracking := mem.Tracking_Allocator {};
    mem.tracking_allocator_init(&tracking, context.allocator);
    context.allocator = mem.tracking_allocator(&tracking);
    vmcore.ctx = context
    set_formatter()
    before := len(tracking.allocation_map)
    vm := vmcore.initvm()
    mod, err := vmcore.load_module(&vm, os.args[1])
    if _, ok := err.(vmcore.None); !ok {
        fmt.println(err)
        os.exit(1)
    }
    jiterr := vmcore.jit(&vm)
    if jiterr != nil {
        fmt.println("Err = ", jiterr)
        return
    }
    mainFunction: ^vmcore.Function = nil
    mstring.__bind(&vm)
    builtins.__bind(&vm)
    for fn in mod.functions {
        if fn.name == "main" {
            mainFunction = fn
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
discard :: proc($T: typeid, res: T, b: bool) -> T {
    return res
}
