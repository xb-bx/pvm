package mstring
import "../../vmcore"
import "core:fmt"

index_of :: proc "c" (str: ^vmcore.StringObject, c: u16) -> i64 {
    using vmcore
    bptr := get_string_bytes_ptr(str) 
    for i in 0..<str.length {
        if bptr[i] == c {
            return i
        }
    }
    return -1
}
split :: proc "c" (str: ^vmcore.StringObject, delimiter: u16) -> ^vmcore.ArrayHeader {
    context = ctx
    using vmcore
    bptr := get_string_bytes_ptr(str) 
    splits := make([dynamic]^StringObject)
    start := 0
    leng := 0
    for i in 0..<str.length {
        if bptr[i] == delimiter {
            if leng != 0 {
                ptr := transmute(^StringObject)gc_alloc(&vm.gc, cast(int)(size_of(StringObject) + leng * 2))
                ptr.length = cast(i64)leng
                newstr := transmute([^]u16)(transmute(u64)ptr + size_of(StringObject))
                for j in start..<leng {
                    newstr[j - start] = bptr[j]
                }
                append(&splits, transmute(^StringObject)ptr)
            }
            start = int(i) + 1
        }
        leng += 1
    }
    if leng != 0 {
        ptr := transmute(^StringObject)gc_alloc(&vm.gc, cast(int)(size_of(StringObject) + leng * 2))
        ptr.length = cast(i64)leng
        newstr := transmute([^]u16)(transmute(u64)ptr + size_of(StringObject))
        for j in start..<leng {
            newstr[j - start] = bptr[j]
        }
        append(&splits, transmute(^StringObject)ptr)
    }
    array := transmute(^ArrayHeader)(gc_alloc(&vm.gc, cast(int)(size_of(ArrayHeader) + len(splits) * 8)))
    array.length = cast(i64)len(splits)
    elems := transmute([^]^StringObject)(transmute(u64)array + size_of(ArrayHeader))
    for s, i in splits {
        elems[i] = s
    }
    delete(splits)
    return transmute(^ArrayHeader)array
} 
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
