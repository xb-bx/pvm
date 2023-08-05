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
                ptr := gc_alloc_string(vm, cast(i64)leng)
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
        ptr := gc_alloc_string(vm, cast(i64)leng)
        newstr := transmute([^]u16)(transmute(u64)ptr + size_of(StringObject))
        for j in start..<leng {
            newstr[j - start] = bptr[j]
        }
        append(&splits, transmute(^StringObject)ptr)
    }
    array := gc_alloc_array(vm, cast(i64)len(splits), make_array(vm, vm.primitiveTypes[PrimitiveType.String]))
    array.length = cast(i64)len(splits)
    elems := transmute([^]^StringObject)(transmute(u64)array + size_of(ArrayHeader))
    for s, i in splits {
        elems[i] = s
    }
    delete(splits)
    return transmute(^ArrayHeader)array
} 
concat :: proc "c" (array: ^vmcore.ArrayHeader, join: ^vmcore.StringObject) -> ^vmcore.StringObject {
    using vmcore
    context = ctx
    gc_add_temp_root(&vm.gc, &array.header)
    gc_add_temp_root(&vm.gc, &join.header)
    totallength: i64 = 0
    for i in 0..<array.length {
        totallength += get_item(^StringObject, array, i).length
    }
    if join != nil {
        totallength += (array.length - 1) * join.length
    }
    resultString := gc_alloc_string(vm, totallength)
    resultString.length = totallength
    chars := transmute([^]u16)(transmute(u64)resultString + size_of(StringObject))
    pos: i64 = 0
    for i in 0..<array.length {
        str := get_item(^StringObject, array, i)
        for j in 0..<str.length {
            chars[pos + j] = get_char(str, j) 
        }
        pos += str.length
        if join != nil && i != array.length - 1 {
            for j in 0..<join.length {
                chars[pos + j] = get_char(join, j) 
            }
            pos += join.length
        }
    }
    gc_remove_last_roots(&vm.gc, 2)
    return resultString
}
array_to_string :: proc "c" (array: ^vmcore.ArrayHeader, length: i64) -> ^vmcore.StringObject {
    using vmcore
    context = {}
    if length > array.length || length <= 0 {
        out_of_bounds(length)
    }
    ptr := gc_alloc_string(vm, length)
    bptr := transmute([^]u16)(transmute(u64)ptr + size_of(StringObject))
    elems := transmute([^]u16)(transmute(u64)array + size_of(ArrayHeader))
    for i in 0..<length {
        bptr[i] = elems[i]
    }
    return ptr

}
vm: ^vmcore.VM = nil
