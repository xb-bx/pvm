package mstring
import "../../vmcore"


array_to_string :: proc "c" (array: ^vmcore.ArrayHeader, length: i64) -> ^vmcore.StringObject {
    using vmcore
    context = {}
    if length > array.length || length <= 0 {
        out_of_bounds(length)
    }
    ptr := gc_alloc(&vm.gc, cast(int)(size_of(StringObject) + length * 2))
    bptr := transmute([^]u16)(transmute(u64)ptr + size_of(StringObject))
    elems := transmute([^]u16)(transmute(u64)array + size_of(ArrayHeader))
    for i in 0..<length {
        bptr[i] = elems[i]
    }
    str := transmute(^StringObject)ptr
    str.length = length
    return str

}
vm: ^vmcore.VM = nil
