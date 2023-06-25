package pvm
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
// import "core:sys/windows"
Tuple :: struct($T1, $T2: typeid) {
    first: T1,
    second: T2,
}
tuple :: proc(fst: $T1, snd: $T2) -> Tuple(T1, T2) {
    return Tuple(T1, T2) { first = fst, second = snd }
}
Field :: struct {
    name: string,
    type: ^Type,
    offset: int,
}
Module :: struct {
    name: string,
    typeImports: []^Type,
    types: map[string]^Type,
    functionImports: []^Function,
    functions: []^Function,
    typedescriptors: []^Type,
    strings: []^StringObject,
}
StringObject :: struct {
    header: ObjectHeader,
    length: i64,
}
Function :: struct {
    name: string,
    args: []^Type,
    locals: []^Type,
    retType: ^Type,
    instructions: []Instruction,
    module: ^Module,
    jitted_body: MemBlock, 
    jmp_body: MemBlock,
}
Instruction :: struct {
    opcode: OpCode,
    operand: u64,
}
OpCode :: enum {
    PushI64,
    PushU64,
    PushI32,
    PushU32,
    PushI16,
    PushU16,
    PushI8,
    PushU8,
    PushF64,
    PushF32,
    PushTrue,
    PushFalse,
    PushNull,
    PushChar,
    PushString,
    Pop,
    Call,
    Ret,
    Add,
    Sub,
    Mul, 
    Div,
    GT,
    LT,
    EQ,
    Not, 
    Jmp,
    Jtrue,
    NewObj,
    Box, 
    Unbox,
    SetLocal,
    PushLocal,
    Neg,
    GetIndex,
    GetIndexRef,
    SetIndex,
    GetFieldRef,
    GetField,
    SetField,
    GetLength,
    RefLocal,
    StoreRef,
    Deref,
    Dup,
    ToRawPtr,
    IsInstanceOf,
    UnboxAs,
    Cast,
    Conv,
}

VM :: struct {
    modules: map[string]^Module,
    primitiveTypes: map[PrimitiveType]^Type,
    descriptors: [dynamic]^Type,
    arrays: map[^Type]^Type,
    boxes: map[^Type]^Type,
    refs: map[^Type]^Type,
    gc: GC,
}
Chunk :: struct {
    data: rawptr,
    size: int,
}
GC :: struct {
    chunks: [dynamic]^Chunk,
    free_places: [dynamic]FreePlace,
}
FreePlace :: struct {
    chunk: ^Chunk,
    offset: int,
    size: int,
}
DEFAULT_CHUNK_SIZE :: 1024 * 128 
GC_ALLIGNMENT :: 128
gc_init :: proc(using gc: ^GC) {
    gc.chunks = make([dynamic]^Chunk)
    gc.free_places = {}
    gc.free_places = make([dynamic]FreePlace)
    gc_new_chunk(gc)
}
alloced := 0
gc_alloc :: proc(using gc: ^GC, size: int) -> rawptr {
    alloced += 1
    alligned_size := 0 
    if size % GC_ALLIGNMENT != 0 {
        alligned_size = size + GC_ALLIGNMENT - size % GC_ALLIGNMENT
    } 
    place := gc_find_freeplace(gc, alligned_size)
    if place == nil {
        gc_collect(gc)        
        place = gc_find_freeplace(gc, alligned_size)
    }
    if place == nil {
        gc_new_chunk(gc, alligned_size)
        place = gc_find_freeplace(gc, alligned_size)
    }
    res := transmute(rawptr)(transmute(int)place.(FreePlace).chunk.data + place.(FreePlace).offset)
    return res 
}
gc_collect :: proc(using gc: ^GC) {
//     freq: windows.LARGE_INTEGER = {}
//     windows.QueryPerformanceFrequency(&freq)
//     start: windows.LARGE_INTEGER = {}
//     windows.QueryPerformanceCounter(&start)
    for frame in stacktrace {
// 
//         framedata := transmute([^]int)(transmute(int)frame.stack - cast(int)frame.stack_size)
//         for i in 0..<(frame.stack_size / 8) {
//             gc_visit_pointer(gc, framedata[i]) 
//         }     
        frameptr := transmute(int)frame.stack
        frameend := frameptr - cast(int)frame.stack_size
        for frameptr >= frameend {
            gc_visit_pointer(gc, (transmute(^int)frameptr)^)
            frameptr -= 8 
        }
    }
    freed := 0
    for chunk in chunks {
        ptr: int = 0
        for ptr < chunk.size {
            object := (transmute(^ObjectHeader)(ptr + transmute(int)chunk.data))
            if object.type == nil {
                ptr += GC_ALLIGNMENT
            }
            else {
                if object.visited == 0 {
                    alligned_size: int = cast(int)object.size
                    if object.size % GC_ALLIGNMENT != 0 {
                        alligned_size = cast(int)object.size + GC_ALLIGNMENT - cast(int)object.size % GC_ALLIGNMENT
                    } 
//                     if len(free_places) != 0 {
//                         prev := &free_places[len(free_places) - 1] 
//                         if prev.chunk == chunk && prev.offset + prev.size == ptr {
//                             prev.size += alligned_size
//                         }
//                         else {
//                             append(&free_places, FreePlace { chunk, ptr, alligned_size })
//                         }
//                     }
//                     else {
                        append(&free_places, FreePlace { chunk, ptr, alligned_size })
//                     }
                    ptr += alligned_size
                    assert(alligned_size != 0, "OPPS")
                    freed += 1
                    runtime.mem_zero(object, alligned_size) 
                }
                else {
                    object.visited = 0
                    alligned_size: int = cast(int)object.size
                    if object.size % GC_ALLIGNMENT != 0 {
                        alligned_size = cast(int)object.size + GC_ALLIGNMENT - cast(int)object.size % GC_ALLIGNMENT
                    } 
                    assert(alligned_size != 0, "OPPS")
                    ptr += alligned_size
                }
            }
        }
    }
    i := 0
    for i + 1 < len(free_places) {
        curr := &free_places[i]
        next := &free_places[i + 1] 
        if next.chunk == curr.chunk && next.offset == curr.offset + curr.size {
            curr.size += next.size
            remove_range(&free_places, i + 1, i + 2)
        } 
        i += 1
    }
//     end: windows.LARGE_INTEGER = {}
//     windows.QueryPerformanceCounter(&end)
//     fmt.println((end - start) * 1000000 / freq)
//     fmt.println(gc_stat_free_mem(gc))
//     fmt.println(alloced, freed)
}
gc_stat_free_mem :: proc(using gc: ^GC) -> int {
    size := 0
    for f in free_places {
        size += f.size
    }
    return size
}
gc_visit_pointer :: proc(using gc: ^GC, ptr: int) {
    if ptr % GC_ALLIGNMENT != 0 {
        return
    }
    chunk: ^Chunk = nil
    for i in gc.chunks {
        dataint := transmute(int)i.data
        if ptr >= dataint && ptr < dataint + i.size {
            chunk = i
            break
        }
    }
    if chunk == nil {
        return
    }
    obj := transmute(^ObjectHeader)ptr
    if obj.visited == 1 {
        return
    }
    obj.visited = 1
    if type_is(PrimitiveType, obj.type) {
        return
    }
    if type_is(ArrayType, obj.type) {
        array := transmute(^ArrayHeader)obj
        elemtype := obj.type.(ArrayType).underlaying
        if type_is_pointertype(elemtype) {
            for i in 0..<array.length {
                p := transmute(^int)(ptr + size_of(ArrayHeader) + cast(int)i*8)

                gc_visit_pointer(gc, p^)
            }
        }
        else if type_is(CustomType, elemtype) {
            for i in 0..<array.length {
                p := transmute(int)(ptr + size_of(ArrayHeader) + cast(int)i*get_type_size(elemtype))
                gc_visit_object(gc, elemtype, p)
            }
        }
    }
    else if type_is(CustomType, obj.type) {
        gc_visit_object(gc, obj.type, ptr + size_of(ObjectHeader))
    }
}
gc_visit_object :: proc(using gc: ^GC, type: ^Type, ptr: int) {
    for field in type.(CustomType).fields {
        if type_is_pointertype(field.type) {
            gc_visit_pointer(gc, (transmute(^int)(ptr + field.offset))^)
        }
        else if type_is(CustomType, field.type) {
            gc_visit_object(gc, field.type, ptr + field.offset)
        }
    }    
}
gc_find_freeplace :: proc(using gc: ^GC, size: int) -> Maybe(FreePlace) {
    for i in 0..<len(gc.free_places) {
        place := &gc.free_places[i]
        if place.size == size {
            res := place^
            remove_range(&gc.free_places, i, i + 1)
            return res
        }
        else if place.size > size {
            res: FreePlace = { place.chunk, place.offset, size }
            place.offset += size
            place.size -= size
            return res
        }
    }
    return nil
}
gc_new_chunk :: proc(using gc: ^GC, size: int = DEFAULT_CHUNK_SIZE) {
    fmt.println("CHUNKIE WAKIE")
    data := mem.alloc(size, GC_ALLIGNMENT)
    if data == nil {
        panic("Failed to allocate memory")
    }    
    chunk := new(Chunk)
    chunk.data = data
    chunk.size = size
    freeplace := FreePlace { chunk, 0, size }
    append(&chunks, chunk)
    append(&gc.free_places, freeplace)
}
make_array :: proc(using vm: ^VM, type: ^Type) -> ^Type {
    if res, ok := arrays[type]; ok {
        return res
    }
    t := new(Type)
    t^ = ArrayType {
        underlaying = type,
    }
    arrays[type] = t
    return t
}
make_box :: proc(using vm: ^VM, type: ^Type) -> ^Type {
    if res, ok := boxes[type]; ok {
        return res
    }
    t := new(Type)
    t^ = BoxedType {
        underlaying = type,
    }
    boxes[type] = t
    return t
}
make_ref :: proc(using vm: ^VM, type: ^Type) -> ^Type {
    if res, ok := refs[type]; ok {
        return res
    }
    t := new(Type)
    t^ = RefType {
        underlaying = type,
    }
    refs[type] = t
    return t
}
find :: proc($T: typeid, $D: typeid, slice: []^T, data: ^D,  prc: proc(^T, ^D) -> bool) -> ^T {
   for i in slice {
        if i == nil {
            continue
        }
        if prc(i, data) {
            return i
        }
   } 
   return nil
}
initvm :: proc() -> VM {
    pmtypes := make(map[PrimitiveType]^Type)
    for i in 0..=cast(u8)PrimitiveType.Void {
        type := new(Type)
        type^ = cast(PrimitiveType)i
        pmtypes[cast(PrimitiveType)i] = type
    }
    gc: GC = {}
    gc_init(&gc)
    return VM {
        modules = make(map[string]^Module),
        refs = make(map[^Type]^Type),
        arrays = make(map[^Type]^Type),
        boxes = make(map[^Type]^Type),
        primitiveTypes = pmtypes,
        gc = gc,
    }
}
load_module :: proc(using vm: ^VM, name: string) -> (mod: ^Module, err: VMError) {
    if mod, ok := modules[name]; ok {
        return mod, none
    }
    slice := []string {name, ".mod"}
    modfile := strings.concatenate(slice)
    defer delete(modfile)
    return load_module_from_file(vm, modfile)
}

load_module_from_file :: proc(using vm: ^VM, file: string) -> (mod: ^Module, err: VMError) {
    bytes, ok := os.read_entire_file(file)
    defer {
        delete(bytes)
    }
    if !ok {
        return nil, module_not_found(strings.clone(file))
    }
    reader := Reader { bytes = bytes, position = 0 } 
    b: u8 = 0
    name := ""
    name, ok = read_string(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    defer if mod == nil {
        delete(name)
    }
    importCount: u32 = 0
    importCount, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    imports := make([]^Module, importCount)
    defer if mod == nil {
        delete(imports)
    }
    for i in 0..<importCount {
        modname := ""
        modname, ok = read_string(&reader)
        defer {
            delete(modname)
        }
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        imports[i], err = load_module(vm, modname)
        if _, ok = err.(None); !ok {
            return nil, err
        }
    }
    importCount, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    typeImports := make([]^Type, importCount)
    defer if mod == nil {
        delete(typeImports)
    }
    for i in 0..<importCount {
        mod: u32 = 0
        mod, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        typename: string = ""
        typename, ok = read_string(&reader)
        defer delete(typename)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        if cast(int)mod > len(imports) || imports[mod] == nil {
            return nil, type_not_found(typename)
        } 
        found: ^Type = nil
        if found, ok = imports[mod].types[typename]; !ok {
            return nil, type_not_found(typename)
        }
        typeImports[i] = found
    }
    typedefinitions: u32 = 0
    typedefinitions, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    types := make(map[string]^Type)
    defer if mod == nil {
        for k, type in types {
            if type == nil {
                continue
            }
            delete(type.(CustomType).name)
            delete(type.(CustomType).fields)
//             delete_type(type)
        }
        delete(types)

    }
    typesArray := make([]^Type, typedefinitions)
    defer delete(typesArray)
    for i in 0..<typedefinitions {
        typename := ""
        typename, ok = read_string(&reader) 
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        if typename in types {
            return nil, type_redefinition(typename)
        }
        type: Type = CustomType {
            name = typename,
            fields = make([dynamic]^Field),
            size = -1,
        }
        typeref := new_clone(type)
        types[typename] = typeref
        typesArray[i] = typeref
    }
    typedescriptorscount: u32 = 0
    typedescriptorscount, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    typedescriptors := make([]^Type, typedescriptorscount)
    defer if mod == nil {
        for t in typedescriptors {
            if t != nil {
//                 delete_type(t)
            }
        }
        delete(typedescriptors)
    }
    for i in 0..<typedescriptorscount {
        descriptor := parse_type_descriptor(&reader, vm, typeImports, typesArray) 
        if descriptor == nil {
            return nil, corrupted_module(strings.clone(file))
        }
        typedescriptors[i] = descriptor
    }
    fields: u32 = 0
    fields, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    for i in 0..<fields {
        typeindex:u32 = 0
        typeindex, ok = read_u32(&reader)
        if !ok || cast(int)typeindex >= len(typesArray) {
            return nil, corrupted_module(strings.clone(file))
        }
        type := &typesArray[typeindex].(CustomType)
        fieldname := ""
        fieldname, ok = read_string(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        // TODO: Add check that type already has field with name fieldname
//         if fieldname in type.fields {
//             return nil, corrupted_module(strings.clone(file))
//         }
        typedescriptor: u32 = 0
        typedescriptor, ok = read_u32(&reader)
        if !ok || cast(int)typedescriptor >= len(typedescriptors) {
            return nil, corrupted_module(strings.clone(file))
        }
        if type_is(RefType, typedescriptors[typedescriptor]) {
            return nil, field_of_ref_type(strings.clone(file), strings.clone(fieldname));
        }
        append(&type.fields, new_clone(Field{name = fieldname, type = typedescriptors[typedescriptor]}))
    }
    functionimports: u32 = 0
    functionimports, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    fnimports := make([]^Function, functionimports)
    defer if mod == nil {
        delete(fnimports)
    }
    for i in 0..<functionimports {
        moduleindex:u32 = 0
        fnname := ""
        moduleindex, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        fnname, ok = read_string(&reader)
        defer delete(fnname)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        if cast(int)moduleindex > len(imports) {
            return nil, corrupted_module(strings.clone(file))
        }
        function := find(Function, string, imports[moduleindex].functions, &fnname, proc(fn: ^Function, name: ^string) -> bool 
        {
            return name^ == fn.name
        })
        if function == nil {
            return nil, function_not_found(strings.clone(fnname))
        }
        fnimports[i] = function 
    }
    functiondefs: u32 = 0
    functiondefs, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    functions := make([]^Function, functiondefs)
    defer if mod == nil {
        for fn in functions {
            if fn != nil {
                delete(fn.name)
                delete(fn.args)
                delete(fn.locals)
                delete(fn.instructions)
            }
        }
        delete(functions)
    }
    functionOffsets := make(map[string]Tuple(u32, u32))
    result := new(Module)
    defer if mod == nil {
        free(result)
    }
    for i in 0..<functiondefs {
        fnname:= ""
        fnname, ok = read_string(&reader)
        if !ok || find(Function, string, functions, &fnname, proc(fn: ^Function, name: ^string) -> bool { return name^ == fn.name }) != nil {
            return nil, corrupted_module(strings.clone(file))
        }
        argc: u32 = 0
        localsc: u32 = 0
        argc, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        args := make([]^Type, argc)
        for argi in 0..<argc {
            arg: u32 = 0
            arg, ok = read_u32(&reader)
            if cast(int)arg >= len(typedescriptors) {
                return nil, corrupted_module(strings.clone(file))
            }
            args[argi] = typedescriptors[arg]
        }
        localsc, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        locals := make([]^Type, localsc)
        for locali in 0..<localsc {
            local: u32 = 0
            local, ok = read_u32(&reader)
            if cast(int)local >= len(typedescriptors) {
                return nil, corrupted_module(strings.clone(file))
            }
            locals[locali] = typedescriptors[local]
        }
        ret: u32 = 0
        ret, ok = read_u32(&reader)
        if !ok || cast(int)ret >= len(typedescriptors) {
            return nil, corrupted_module(strings.clone(file))
        }
        retType := typedescriptors[ret]
        if type_is(RefType, retType) {
            return nil, cant_return_reference_from_function(strings.clone(file), strings.clone(fnname))
        }
        bodystart: u32 = 0
        bodylen: u32 = 0
        bodystart, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        bodylen, ok = read_u32(&reader)
        if !ok {
            return nil, corrupted_module(strings.clone(file))
        }
        functionOffsets[fnname] = tuple(bodystart, bodylen)
        fn := new(Function)
        fn.name = fnname
        fn.args = args
        fn.locals = locals
        functions[i] = fn
        fn.module = result
        fn.retType = retType
    }
    stringcount: u32 = 0
    stringcount, ok = read_u32(&reader)
    if !ok {
        return nil, corrupted_module(strings.clone(file))
    }
    strs := make([]^StringObject, stringcount)
    strdata := make([dynamic]u16, 32)
    defer delete(strdata)
    for str in 0..<stringcount {
        clear_dynamic_array(&strdata)
        ch: u16 = 0;
        ch, ok = read_u16(&reader)
        for ok && ch != 0 {
            append(&strdata, ch)
            ch, ok = read_u16(&reader)
        }
        strobj := cast(^StringObject)mem.alloc(size_of(StringObject) + len(strdata) * 2)
        strobj.header.type = vm.primitiveTypes[PrimitiveType.String]
        strobj.length = cast(i64)len(strdata)
        strptr := transmute([^]u16)(transmute(u64)strobj + size_of(ObjectHeader) + 8)
        for c, i in strdata {
            strptr[i] = c
        }
        strs[str] = strobj
    } 
    for f in functions {
        if f == nil {
            continue
        }
        tuple  := functionOffsets[f.name]
        if !parse_instructions(&reader, tuple.first, tuple.second, f) {
            return nil, corrupted_module(strings.clone(file))
        }
    }
    result.name = name
    result.typeImports = typeImports
    result.types = types
    result.functionImports = fnimports
    result.functions = functions
    result.typedescriptors = typedescriptors
    result.strings = strs
    modules[name] = result
    failed := calculate_types(vm, result)
    if failed != nil {
        return nil, recursive_type(strings.clone(failed.(CustomType).name)) 
    }
    return result, none
}
calculate_types :: proc(vm: ^VM, module: ^Module) -> ^Type {
    for _, type in module.types {
        if !calculate_type(type) {
            return type
        }
    }
    return nil
}
get_type_size :: proc(type: ^Type, primitive_aligned: bool = false) -> int {
    switch in type {
        case ArrayType, BoxedType, RefType:
            return 8
        case PrimitiveType:
            switch type.(PrimitiveType) {
                case .F64, .I64, .U64, .Any, .String:
                    return 8
                case .F32, .I32, .U32:
                    return primitive_aligned ? 8 : 4
                case .I16, .U16, .Char:
                    return primitive_aligned ? 8 : 2
                case .I8, .U8, .Boolean:
                    return primitive_aligned ? 8 : 1
                case .Void:
                    return 0
            }
        case CustomType:
            if type.(CustomType).size == -1 {
                if !calculate_type(type) {
                    return -1
                }   
            }
            return type.(CustomType).size
    }
    return -1
}

calculate_type :: proc(type: ^Type) -> bool {
    if !type_is(CustomType, type) {
        panic("THAT SHOUD NOT HAPPEN")
    }
    if type.(CustomType).size == -2 {
        return false
    }
    cc := type.(CustomType)
    cc.size = -2
    type^ = cc
    size := 0
    for field in type.(CustomType).fields {
        fieldsize := get_type_size(field.type) 
        if fieldsize < 0 {
            return false
        }
        align := fieldsize > 8 ? 8 : fieldsize;
        if size % align != 0 {
            size += align - (size % align)
        }
        field.offset = size
        size += fieldsize
    }
    if size % 8 != 0 {
        size += 8 - (size % 8)
    }
    (&type.(CustomType)).size = size
    return true
}

function_hasnot_been_jitted :: proc  () {
    panic("called to not jitted function")
}
fnpointer := function_hasnot_been_jitted
parse_instructions :: proc(using reader: ^Reader, start: u32, length: u32, fn: ^Function) -> bool {
    if cast(int)start >= len(bytes) || cast(int)(start + length) > len(bytes) || length == 0 {
        return false
    }
    b: u8 = 0
    position = cast(int)start
    instructions := make([dynamic]Instruction)
    for position < cast(int)(start + length) {
        b = read_byte(reader) or_return
        instr := Instruction{}
        opcode := cast(OpCode)b
        switch opcode {
        case .PushI16, .PushU16, .PushChar:
            op: u16 = 0
            op = read_u16(reader) or_return
            instr = Instruction { opcode = opcode, operand = cast(u64)op }
        case .PushI8, .PushU8:
            op: u8 = 0
            op = read_byte(reader) or_return
            instr = Instruction { opcode = opcode, operand = cast(u64)op }
        case .PushF32:
            fallthrough
        case .Call:
            fallthrough
        case .Jmp:
            fallthrough
        case .Jtrue:
            fallthrough
        case .NewObj:
            fallthrough
        case .SetLocal:
            fallthrough
        case .RefLocal:
            fallthrough
        case .PushLocal:
            fallthrough
        case .GetFieldRef:
            fallthrough
        case .GetField:
            fallthrough
        case .SetField:
            fallthrough
        case .IsInstanceOf, .UnboxAs, .PushI32, .PushU32, .Cast, .Conv, .PushString:
            op: u32 = 0
            op = read_u32(reader) or_return
            instr = Instruction { opcode = opcode, operand = cast(u64)op }
        case .PushF64, .PushU64, .PushI64:
            op: u64 = 0
            op = read_u64(reader) or_return
            instr = Instruction { opcode = opcode, operand = op }
        case .StoreRef,
         .Deref,
         .Pop,
         .Ret,
         .PushTrue,
         .PushFalse,
         .Add,
         .Sub,
         .Mul,
         .Div,
         .GT,
         .LT,
         .EQ,
         .Not,
         .Neg,
         .Dup,
         .Box,
         .Unbox,
         .GetIndex,
         .GetIndexRef,
         .SetIndex,
         .PushNull,
         .GetLength,
         .ToRawPtr:
            instr = Instruction { opcode = opcode, operand = 0 }
        case: 
            fmt.println(opcode)
            panic("Unknown opcode")
        }
        append(&instructions, instr)
    }
    fn.instructions = instructions[:] 
    return true
}
parse_type_descriptor :: proc(using reader: ^Reader, vm: ^VM, imports: []^Type, types: []^Type) -> (res: ^Type) {
    type := new(Type) 
    b: u8 = 0
    ok: bool = false
    b, ok = read_byte(reader) 
    if !ok {
        return nil
    }
    defer if res == nil {
        if type != nil {
            free(type)
        }
    }
    switch b {
        case 0:
            b, ok = read_byte(reader)
            if !ok {
                return nil
            }
            if b > cast(u8)PrimitiveType.Void {
                return nil
            }
            free(type)
            type = nil
            val := vm.primitiveTypes[cast(PrimitiveType)b]
            return val
        case 1: 
            under := parse_type_descriptor(reader, vm, imports, types)
            if under == nil {
                return nil
            }
            type^ = BoxedType {
                underlaying = under,
            }
        case 2: 
            under := parse_type_descriptor(reader, vm, imports, types)
            if under == nil {
                return nil
            }
            type^ = ArrayType {
                underlaying = under,
            }
        case 3:
            under := parse_type_descriptor(reader, vm, imports, types);
            if under == nil {
                return nil
            }
            type^ = RefType {
                underlaying = under,
            }
        case 4:
            index: u32 = 0
            index, ok = read_u32(reader)
            if !ok {
                return nil
            }
            if cast(int)index >= len(imports) {
                if cast(int)index >= len(imports) + len(types) {
                    return nil
                }
                else {
                    free(type)
                    type = types[cast(int)index - len(imports)]
                }
            } 
            else { 
                free(type)
                type = imports[index]
            }
        case:
            return nil
    }
    return type

}


