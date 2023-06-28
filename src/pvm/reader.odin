package pvm
import "core:strings"
import "core:fmt"
Reader :: struct {
    bytes: []u8,
    position: int,
}
read_u64 :: proc(using reader: ^Reader) -> (u64, bool) {
    if position + 8 > len(bytes) {
        return 0, false
    }
    res: u64 = 0
    res |= read_byte_silent(reader, u64) 
    res |= (read_byte_silent(reader, u64) ) << 8
    res |= (read_byte_silent(reader, u64) ) << 16
    res |= (read_byte_silent(reader, u64) ) << 24
    res |= (read_byte_silent(reader, u64) ) << 32 
    res |= (read_byte_silent(reader, u64) ) << 40
    res |= (read_byte_silent(reader, u64) ) << 48
    res |= (read_byte_silent(reader, u64)  << 56) 
    return res, true
}
read_u16 :: proc(using reader: ^Reader) -> (u16, bool) {
    if position + 2 > len(bytes) {
        return 0, false
    }
    res: u16 = 0
    res |= read_byte_silent(reader, u16) & 0xFF
    res |= (read_byte_silent(reader, u16) << 8) 
    return res, true
}
read_u32 :: proc(using reader: ^Reader) -> (u32, bool) {
    if position + 4 > len(bytes) {
        return 0, false
    }
    res: u32 = 0
    res |= read_byte_silent(reader, u32)
    res |= (read_byte_silent(reader, u32) << 8) 
    res |= (read_byte_silent(reader, u32) << 16) 
    res |= (read_byte_silent(reader, u32) << 24) 
    return res, true
}
read_byte :: proc(using reader: ^Reader) -> (u8, bool) {
    if position >= len(bytes) {
        return 0, false
    }
    res := bytes[position]
    position += 1
    return res, true
}
read_byte_silent :: proc(using reader: ^Reader, $T: typeid) -> T {
    res := bytes[position]
    position += 1
//     fmt.printf("%H", res)
    return cast(T)res & 0xff
}
read_string :: proc(using reader: ^Reader) -> (string, bool) {
    cbytes := make([dynamic]u8)
    defer delete(cbytes)
    b, ok := read_byte(reader)
    for b > 0 {
        append(&cbytes, b)
        b, ok = read_byte(reader)
    }
    if !ok {
        return "",false
    }
    
    return strings.clone_from_bytes(cbytes[:]), true
}

