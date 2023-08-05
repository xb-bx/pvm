package builtins
import "../../vmcore"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:math/rand"
import "core:runtime"
import "core:time"
import "core:c"
when ODIN_OS == .Windows do foreign import econio "econio.lib"
when ODIN_OS == .Linux do foreign import econio "econio.a"

foreign {
    econio_rawmode :: proc() ---
    econio_normalmode :: proc() ---
    econio_kbhit :: proc() -> bool ---
    econio_getch :: proc() -> c.int ---
}
rawmode :: proc "c" () {
    econio_rawmode()
}
normalmode :: proc "c" () {
    econio_normalmode()
}
kbhit :: proc "c" () -> bool {
    return econio_kbhit()
}
getch :: proc "c" () -> c.int {
    return econio_getch()
}


vm: ^vmcore.VM = nil
rand :: proc "c" (min: i64, max: i64) -> i64 {
    context = vmcore.ctx
    res := min + (rand.int63() % (max - min))
    return res
}
getkeystate :: proc "c" (key: i64) -> i64 {
    context = vmcore.ctx
    when os.OS == runtime.Odin_OS_Type.Linux {
        panic("NOT IMPLEMENTED")
    }
    else {
        return cast(i64)windows.GetAsyncKeyState(cast(i32)key)
    }
    return 0
}
printi64 :: proc "c" (arg: i64) {
    context = vmcore.ctx
    fmt.println(arg)
}
printbuf: strings.Builder = strings.builder_make_len(128)

printchar :: proc "c" (arg: i64) {
    context = vmcore.ctx
    strings.write_rune(&printbuf, cast(rune)(arg & 0xffff))
}
flush :: proc "c" () {
    context = {}
    fmt.println(strings.to_string(printbuf))
    strings.builder_reset(&printbuf)
}
println :: proc "c" (str: ^vmcore.StringObject) {
    using vmcore
    context = ctx
    if str == nil {
        fmt.println("<nil>")
        return
    }
    s := strings.string_from_ptr(transmute(^byte)(transmute(int)str + size_of(StringObject)), cast(int)str.length * 2)
    fmt.println(s)
 
//     windows.WriteConsoleW(windows.GetStdHandle(windows.STD_OUTPUT_HANDLE), transmute(^u16)(transmute(u64)str + size_of(ObjectHeader) + 8), cast(u32)str.length, nil, nil)
}
gc_mem :: proc "c" () -> int {
    context = vmcore.ctx
    return vmcore.gc_stat_free_mem(&vm.gc)
}
inspect :: proc "c" (obj: ^vmcore.ObjectHeader) {
    using vmcore
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
sleep :: proc "c" (ms: u32) {
    time.sleep(time.Duration(cast(i64)ms) * time.Millisecond)
}
clear ::  proc "c" () {
    context = {}
    fmt.print("\x1b[2J") 
    fmt.print("\x1b[0;0H")
}
