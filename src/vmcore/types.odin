package vmcore

PrimitiveType :: enum {
    I64 = 0,
    U64,
    I32,
    U32,
    I16,
    U16,
    I8,
    U8,
    F64,
    F32,
    Char,
    Any,
    String,
    Boolean,
    Void,
}
Type :: union {
    PrimitiveType,
    CustomType,    
    BoxedType,
    ArrayType,
    RefType,
}
BoxedType :: struct {
    underlaying: ^Type,
}
ArrayType :: struct {
    underlaying: ^Type,
}
RefType :: struct {
    underlaying: ^Type,
}
CustomType :: struct {
    name: string,
    fields: [dynamic]^Field,
    size: int,
}
