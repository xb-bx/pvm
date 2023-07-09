package pasm
import "../pvm"

import "core:os"
import "core:bufio"
import "core:io"
import "core:strings"
import "core:mem"
import "core:fmt"
import "core:unicode"
import "core:unicode/utf16"
import "core:strconv"
import "core:slice"
Import :: struct {
    from: Token,
    item: Token,
}
Field :: struct {
    name: Token,
    type: Token,
}
Type :: struct {
    name: Token,
    fields: [dynamic]Field,
}
Variable :: struct {
    name: Token,
    type: Token,
}
None :: struct {}
Id :: struct { using Token }
Integer :: struct { using Token }
TypeDescriptor :: struct { using Token }
FieldOperand :: struct {type: string, field: string }
CharOperand :: struct { using Token }
StringOperand :: struct { using Token }
Operand :: union {
    None,
    Id,
    Integer, 
    TypeDescriptor,
    FieldOperand,
    CharOperand,
    StringOperand,
}
token_to_operand :: proc(token: Token) -> Operand {
    if token.type == TokenType.Id {
        return Id { token }
    }
    else if token.type == TokenType.Integer  {
        return Integer { token }
    }
    else if token.type == TokenType.TypeDescriptor {
        return TypeDescriptor { token }
    }
    else if token.type == TokenType.Field {
        splited := strings.split(token.value, ":")
        return FieldOperand { type = splited[0], field = splited[1] }
    }
    else if token.type == TokenType.Char {
        return CharOperand { token }
    }
    else if token.type == TokenType.String {
        return StringOperand { token }
    }
    panic("Unsupported token type")
}
Instruction :: struct {
    opcode: Token,
    operand: Operand,
    operand_token: Token,
}
Function :: struct {
    name: Token,
    args: [dynamic]Variable,
    locals: [dynamic]Variable,
    returnType: Token,
    body: [dynamic]Instruction,
}
Program :: struct {
    name: Token,
    imports: [dynamic]Import,
    typeImports: [dynamic]Import,
    functionImports: [dynamic]Import,
    typeDefinitions: [dynamic]Type,
    functionDefinitions: [dynamic]Function,
    typeDescriptors: map[string]pvm.Tuple(int, [dynamic]u8),
    strings: [dynamic]string,
    strings_map: map[string]int,
    vm: pvm.VM,
}
read_file_to_string :: proc(file: string) -> (res: []rune, oky: bool) {
    handle, err := os.open(file)
    if err != os.ERROR_NONE {
        return nil, false
    }
    stream := os.stream_from_handle(handle)
    reader := bufio.Reader{}
    read, ok := io.to_reader(stream)
    bufreader := bufio.Reader{}
    bufio.reader_init(&bufreader, read)
    defer bufio.reader_destroy(&bufreader)
    runes := make([dynamic]rune) 
    defer delete(runes)
    run, _, error := bufio.reader_read_rune(&bufreader)
    for error == io.Error.None {
        append(&runes, run)
        run, _, error = bufio.reader_read_rune(&bufreader)
    }
    result := make([]rune, len(runes))
    for r, i in runes {
        result[i] = r
    }
    return result, true 
}
Tokenizer :: struct {
    source: []rune,
    tokens: [dynamic]Token,
    position: int,
    line: int,
    col: int,
    builder: strings.Builder,
}
Token :: struct {
    type: TokenType,
    value: string,
    line: int,
    col: int,
}
TokenType :: enum {
    Id, 
    Integer,
    FloatingPoint,
    Keyword,
    Instruction,
    Label,
    TypeDescriptor,
    EOF,
    LP,
    RP,
    Field,
    Char,
    String,
}
tokenizer_init :: proc(using tokenizer: ^Tokenizer) {
    tokens = make([dynamic]Token)
    builder = strings.Builder{}
    strings.builder_init(&builder)
    position = 0
    line = 1
    col = 1
}
keywords := map[string]string {
    "module" = "module",
    "import" = "import",
    "type" = "type",
    "fn" = "fn",
    "end" = "end",
    "locals" = "locals",
    "from" = "from",
}
instructions := map[string]pvm.OpCode {
    "pushi64" = pvm.OpCode.PushI64,
    "pushu64" = pvm.OpCode.PushU64,
    "pushi32" = pvm.OpCode.PushI32,
    "pushu32" = pvm.OpCode.PushU32,
    "pushi16" = pvm.OpCode.PushI16,
    "pushu16" = pvm.OpCode.PushU16,
    "pushi8" = pvm.OpCode.PushI8,
    "pushu8" = pvm.OpCode.PushU8,
    "pushstr" = pvm.OpCode.PushString,
    "pushlocal" = pvm.OpCode.PushLocal,
    "pop" = pvm.OpCode.Pop,
    "add" = pvm.OpCode.Add,
    "sub" = pvm.OpCode.Sub,
    "mul" = pvm.OpCode.Mul,
    "div" = pvm.OpCode.Div,
    "setlocal" = pvm.OpCode.SetLocal,
    "jmp" = pvm.OpCode.Jmp,
    "jtrue" = pvm.OpCode.Jtrue,
    "gt" = pvm.OpCode.GT,
    "lt" = pvm.OpCode.LT,
    "eq" = pvm.OpCode.EQ,
    "not" = pvm.OpCode.Not,
    "box" = pvm.OpCode.Box,
    "unbox" = pvm.OpCode.Unbox,
    "ret" = pvm.OpCode.Ret,
    "neg" = pvm.OpCode.Neg,
    "call" = pvm.OpCode.Call,
    "pushtrue" = pvm.OpCode.PushTrue,
    "pushfalse" = pvm.OpCode.PushFalse,
    "newobj" = pvm.OpCode.NewObj,
    "getfield" = pvm.OpCode.GetField,
    "getfieldref" = pvm.OpCode.GetFieldRef,
    "getlength" = pvm.OpCode.GetLength,
    "setfield" = pvm.OpCode.SetField,
    "getindex" = pvm.OpCode.GetIndex,
    "getindexref" = pvm.OpCode.GetIndexRef,
    "setindex" = pvm.OpCode.SetIndex,
    "reflocal" = pvm.OpCode.RefLocal,
    "storeref" = pvm.OpCode.StoreRef,
    "deref" = pvm.OpCode.Deref,
    "torawptr" = pvm.OpCode.ToRawPtr,
    "isinstanceof" = pvm.OpCode.IsInstanceOf,
    "unboxas" = pvm.OpCode.UnboxAs,
    "pushnull" = pvm.OpCode.PushNull,
    "cast" = pvm.OpCode.Cast,
    "conv" = pvm.OpCode.Conv,
    "pushchar" = pvm.OpCode.PushChar,
    "dup" = pvm.OpCode.Dup,
}

tokenizer_destroy :: proc(using tokenizer: ^Tokenizer) {
    delete(tokens)
}
tokenize :: proc(using tokenizer: ^Tokenizer, code: []rune) -> []Token {
    source = code
    for position < len(source) {
        if source[position] == ';' {
            for position < len(source) && source[position] != '\n' {
                position += 1 
                col += 1
            }
        }
        if unicode.is_letter(source[position]) {
            append(&tokens, tokenize_id(tokenizer))
        }
        else if source[position] == '-' || unicode.is_digit(source[position]) {
            append(&tokens, tokenize_number(tokenizer))
        }
        else if source[position] == ':' {
            col += 1
            position += 1
            token := tokenize_id(tokenizer)
            token.type = TokenType.Label
            append(&tokens, token)
        }
        else if source[position] == '*' || source[position] == '$' || source[position] == '&' {
            append(&tokens, tokenize_descriptor(tokenizer))
        }
        else if source[position] == '(' {
            position += 1
            append(&tokens, Token {type = TokenType.LP})
        } 
        else if source[position] == ')' {
            position += 1
            append(&tokens, Token {type = TokenType.RP})
        } 
        else if source[position] == '\n' {
            col = 1
            line += 1
            position += 1
        }
        else if source[position] == '\'' {
            append(&tokens, tokenize_char(tokenizer))
        }
        else if source[position] == '"' {
            append(&tokens, tokenize_string(tokenizer))
        }
        else {
            position += 1
            col += 1
        }
    }
    append(&tokens, Token{ type = TokenType.EOF, value = ""})
    return tokens[:]
}
handle_eof :: proc (using tokenizer: ^Tokenizer) {
    if position >= len(source) {
        fmt.printf("ERROR: EOF at %v:%v\n", line, col)
        os.exit(1)
    }
}
error :: proc (using tokenizer: ^Tokenizer, err: string) {
    fmt.printf("ERROR: %v at %v:%v\n", err, line, col)
    os.exit(1)
}
tokenize_string:: proc(using tokenizer: ^Tokenizer) -> Token {
    column := col
    col += 1
    position += 1
    handle_eof(tokenizer)
    for position < len(source) && source[position] != '"' {
//         fmt.println(position, source[position])
        if source[position] == '\\' {
            position += 1
            col += 1
            handle_eof(tokenizer)
            switch source[position] {
                case '\\', '\"':
                    strings.write_rune(&builder, source[position]);
                case 't':
                    strings.write_rune(&builder, '\t')
                case 'n':
                    strings.write_rune(&builder, '\n')
                case:
                    error(tokenizer, "Unknown escape sequence")
            }
            position += 1
            col += 1
        }
        else {
            strings.write_rune(&builder, source[position]);
            position += 1
            col += 1
        }
    }
    handle_eof(tokenizer)
    if source[position] != '\"' {
        fmt.println(cast(u16)source[position])
        error(tokenizer, "Expected '")
    }
    position += 1
    col += 1
    value := strings.clone_from_bytes(builder.buf[:strings.builder_len(builder)])
    strings.builder_reset(&builder)
    return Token { value = value, type = TokenType.String, line = line, col = column }
}
tokenize_char :: proc(using tokenizer: ^Tokenizer) -> Token {
    column := col
    col += 1
    position += 1
    handle_eof(tokenizer)
    if source[position] == '\\' {
        position += 1
        col += 1
        handle_eof(tokenizer)
        switch source[position] {
            case '\\', '\'':
                strings.write_rune(&builder, source[position]);
            case 't':
                strings.write_rune(&builder, '\t')
            case 'n':
                strings.write_rune(&builder, '\n')
            case:
                error(tokenizer, "Unknown escape sequence")
        }
        position += 1
        col += 1
    }
    else {
        strings.write_rune(&builder, source[position]);
        position += 1
        col += 1
    }
    handle_eof(tokenizer)
    if source[position] != '\'' {
        fmt.println(cast(u16)source[position])
        error(tokenizer, "Expected '")
    }
    position += 1
    col += 1
    value := strings.clone_from_bytes(builder.buf[:strings.builder_len(builder)])
    strings.builder_reset(&builder)
    return Token { value = value, type = TokenType.Char, line = line, col = column }
}
tokenize_descriptor :: proc(using tokenizer: ^Tokenizer) -> Token {
    column := col
    state := 0
    for position < len(source) {
        if state == 0 {
            if source[position] == '*' || source[position] == '$' || source[position] == '&' {
                strings.write_rune(&builder, source[position]);
            }
            else if unicode.is_letter(source[position]) {
                state = 1
                strings.write_rune(&builder, source[position]);
            }
            else {
                break
            }
            col += 1
            position += 1
        }
        else {
            if unicode.is_letter(source[position]) || unicode.is_digit(source[position]) {
                strings.write_rune(&builder, source[position]);
            }
            else {
                break;
            }
            col += 1;
            position += 1;

        }
    }
    value := strings.clone_from_bytes(builder.buf[:strings.builder_len(builder)])
    strings.builder_reset(&builder)
    return Token { value = value, type = TokenType.TypeDescriptor, line = line, col = column }
}
tokenize_number :: proc(using tokenizer: ^Tokenizer) -> Token {
    column := col
    if source[position] == '-' {
        strings.write_rune(&builder, source[position])
        position += 1
        col += 1
    }
    for position < len(source) && unicode.is_digit(source[position]) {
        strings.write_rune(&builder, source[position])
        position += 1
        col += 1
    }
    value := strings.clone_from_bytes(builder.buf[:strings.builder_len(builder)])
    strings.builder_reset(&builder)
    return Token { value = value, type = TokenType.Integer, line = line, col = column }
}
continue_tokenize_field :: proc(using tokenizer: ^Tokenizer) -> Token { 
    tok := tokenize_id(tokenizer)
    tok.type = TokenType.Field;
    return tok;
}
tokenize_id :: proc(using tokenizer: ^Tokenizer) -> Token {
    column := col
    for position < len(source) && (unicode.is_letter(source[position]) || unicode.is_digit(source[position]) || source[position] == '_') {
        strings.write_rune(&builder, source[position])
        position += 1
        col += 1
    }
    if position < len(source) && source[position] == ':' {
        strings.write_rune(&builder, ':')
        position += 1;
        return continue_tokenize_field(tokenizer)
    }
    value := strings.clone_from_bytes(builder.buf[:strings.builder_len(builder)])
    strings.builder_reset(&builder)
    type := TokenType.Id
    if _, ok := keywords[value]; ok {
        type = TokenType.Keyword
    }
    else if _, ok := instructions[value]; ok {
        type = TokenType.Instruction
    }
    
    return Token { value = value, type = type, line = line, col = column, }
}
Parser :: struct {
    position: int,
    tokens: []Token,
}
program_init :: proc(using program: ^Program) {
    imports = make([dynamic]Import)
    typeImports = make([dynamic]Import)
    functionImports = make([dynamic]Import)
    typeDefinitions = make([dynamic]Type)
    functionDefinitions = make([dynamic]Function);
    typeDescriptors = make(map[string]pvm.Tuple(int, [dynamic]u8))
    strings = make([dynamic]string)
    strings_map = make(map[string]int)
    vm = pvm.initvm()
}
parser_init :: proc(using parser: ^Parser) {
    position = 0
}
parse :: proc(using parser: ^Parser, toks: []Token) -> (prog: Program, isok: bool) {
    tokens = toks
    program := Program{}
    program_init(&program);
    _, ok := parse_keyword(parser, "module"); 
    if !ok {
        return program, false;
    }
    name := Token{}
    name, ok = parse_token(parser, TokenType.Id)
    if !ok {
        return program, false;
    }
    program.name = name
    for position < len(tokens) {
        if _, ok = parse_keyword(parser, "import"); ok {
            if _, ok = parse_keyword(parser, "type"); ok {
                name, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                _, ok = parse_keyword(parser, "from")
                if !ok {
                    return program, false
                }
                module := Token{}
                module, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                append(&program.typeImports, Import { from = module, item = name })
            }            
            else if _, ok = parse_keyword(parser, "fn"); ok {
                name, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                _, ok = parse_keyword(parser, "from")
                if !ok {
                    return program, false
                }
                module := Token{}
                module, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                append(&program.functionImports, Import { from = module, item = name })
            }            
            else {
                name, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                append(&program.imports, Import { item = name })
            }
        }
        else if _, ok = parse_keyword(parser, "type"); ok {
            name, ok = parse_token(parser, TokenType.Id)
            if !ok {
                return program, false
            }
            type := Type {}
            type.name = name
            type.fields = make([dynamic]Field)
            _, ok = parse_keyword(parser, "end");
            for !ok {
                name, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                fieldtype := Token{}
                if fieldtype, ok = parse_token(parser, TokenType.Id); ok {}
                else if fieldtype, ok = parse_token(parser, TokenType.TypeDescriptor); ok {}
                else { return program, false } 
                append(&type.fields, Field{name = name, type = fieldtype})
                _, ok = parse_keyword(parser, "end");
            }
            append(&program.typeDefinitions, type)
        }
        else if _, ok = parse_keyword(parser, "fn"); ok {
            name, ok = parse_token(parser, TokenType.Id)
            if !ok {
                return program, false
            }
            _, ok = parse_token(parser, TokenType.LP)
            if !ok {
                return program, false
            }
            fn := Function{ name = name }
            fn.args = make([dynamic]Variable)
            _, ok = parse_token(parser, TokenType.RP)
            for !ok {
                argname := Token{}
                argname, ok = parse_token(parser, TokenType.Id)
                if !ok {
                    return program, false
                }
                argtype := Token{}
                if argtype, ok = parse_token(parser, TokenType.Id); ok {}
                else if argtype, ok = parse_token(parser, TokenType.TypeDescriptor); ok {}
                else { return program, false }
                append(&fn.args, Variable {name = argname, type = argtype })
                _, ok = parse_token(parser, TokenType.RP)
            }
            if fn.returnType, ok = parse_token(parser, TokenType.Id); ok {}
            else if fn.returnType, ok = parse_token(parser, TokenType.TypeDescriptor); ok {}
            else { return program, false }
            fn.locals = make([dynamic]Variable)
            if _, ok = parse_keyword(parser, "locals"); ok {
                _, ok = parse_keyword(parser, "end")
                for !ok {
                    localname := Token{}
                    localname, ok = parse_token(parser, TokenType.Id)
                    if !ok {
                        return program, false
                    }
                    localtype := Token{}
                    if localtype, ok = parse_token(parser, TokenType.Id); ok {}
                    else if localtype, ok = parse_token(parser, TokenType.TypeDescriptor); ok {}
                    else { return program, false }
                    append(&fn.locals, Variable {name = localname, type = localtype })
                    _, ok = parse_keyword(parser, "end")
                }
            } 
            _, ok = parse_keyword(parser, "end")
            fn.body = make([dynamic]Instruction)
            for !ok {
                instruction := Instruction{}
                instruction, ok = parse_instruction(parser)
                if !ok {
                    return program, false
                }
                append(&fn.body, instruction)
                _, ok = parse_keyword(parser, "end")
            }
            append(&program.functionDefinitions, fn)

        }
        else if _, ok = parse_token(parser, TokenType.EOF); ok {
            break
        }
        else {
            return program, false
        }
    }
    return program, true 
}
parse_instruction :: proc(using parser: ^Parser) -> (Instruction, bool) {

    instr, ok := parse_token(parser, TokenType.Instruction)
    if !ok {
        label, islabel := parse_token(parser, TokenType.Label);
        if !islabel {
            
            fmt.println("fuckie wackie", tokens[position])
            return {}, false
        }
        return Instruction{ opcode = label, operand = None {}, operand_token = label }, true
    }

    value := Token{}
    operand := Operand {}
    if value, ok = parse_token(parser, TokenType.Integer); ok { operand = token_to_operand(value) }
    else if value, ok = parse_token(parser, TokenType.Id); ok { operand = token_to_operand(value) }
    else if value, ok = parse_token(parser, TokenType.TypeDescriptor); ok { operand = token_to_operand(value) }
    else if value, ok = parse_token(parser, TokenType.Field); ok { operand = token_to_operand(value) }
    else if value, ok = parse_token(parser, TokenType.Char); ok { operand = token_to_operand(value) }
    else if value, ok = parse_token(parser, TokenType.String); ok { operand = token_to_operand(value) }
    else { operand = None {}}
    return Instruction { opcode = instr, operand = operand, operand_token = value }, true
}
parse_keyword :: proc(using parser: ^Parser, value: string) -> (Token, bool) {
    return parse_token(parser, TokenType.Keyword, value)
}
parse_token :: proc{parse_token_type, parse_token_type_value};
parse_token_type_value :: proc(using parser: ^Parser, type: TokenType, value: string) -> (Token, bool) {
    if tokens[position].type == type && tokens[position].value == value {
        position +=1
        return tokens[position - 1], true
    }
    return tokens[position], false
}
parse_token_type :: proc(using parser: ^Parser, type: TokenType) -> (Token, bool) {
    if tokens[
    position].type == type {
        position +=1
        return tokens[position - 1], true
    }
    return {}, false
}
compile :: proc(using program: ^Program, tokens: []Token) -> (res: []u8, success: bool) {
    result := make([dynamic]u8)
    defer if res == nil {
        delete(result)
    }
    des, _ := create_type_descriptor(program, "i64")
    typeDescriptors["i64"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "u64")
    typeDescriptors["u64"] = pvm.tuple(len(typeDescriptors), des)
    
    des, _ = create_type_descriptor(program, "i32")
    typeDescriptors["i32"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "u32")
    typeDescriptors["u32"] = pvm.tuple(len(typeDescriptors), des)

    des, _ = create_type_descriptor(program, "i16")
    typeDescriptors["i16"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "u16")
    typeDescriptors["u16"] = pvm.tuple(len(typeDescriptors), des)

    des, _ = create_type_descriptor(program, "i8")
    typeDescriptors["i8"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "u8")
    typeDescriptors["u8"] = pvm.tuple(len(typeDescriptors), des)
    
    des, _ = create_type_descriptor(program, "f64")
    typeDescriptors["f64"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "f32")
    typeDescriptors["f32"] = pvm.tuple(len(typeDescriptors), des)
    
    des, _ = create_type_descriptor(program, "any")
    typeDescriptors["any"] = pvm.tuple(len(typeDescriptors), des)

    des, _ = create_type_descriptor(program, "bool")
    typeDescriptors["bool"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "void")
    typeDescriptors["void"] = pvm.tuple(len(typeDescriptors), des)

    des, _ = create_type_descriptor(program, "char")
    typeDescriptors["char"] = pvm.tuple(len(typeDescriptors), des)
    des, _ = create_type_descriptor(program, "string")
    typeDescriptors["string"] = pvm.tuple(len(typeDescriptors), des)

    for t in tokens {
        if t.type == TokenType.TypeDescriptor {
            tuple, ok := typeDescriptors[t.value]
            if !ok {
                desc, okk := create_type_descriptor(program, t.value)
                if !okk {
                    return nil, false
                }
                typeDescriptors[t.value] = pvm.tuple(len(typeDescriptors), desc)
            }
        }
        else if t.type == TokenType.Id {
            if d, found := typeDescriptors[t.value]; !found {
                desc, okk := create_type_descriptor(program, t.value)
                if okk {
                    typeDescriptors[t.value] = pvm.tuple(len(typeDescriptors), desc)
                }
            }
        }
        else if t.type == TokenType.String {
            if _, found := strings_map[t.value]; !found {
                append(&strings, t.value)
                strings_map[t.value] = len(strings) - 1
            }
        }
    }
    append_string(&result, name.value)
    append_u32(&result, cast(u32)len(imports))
    for impor in imports {
        append_string(&result, impor.item.value) 
    }
    append_u32(&result, cast(u32)len(typeImports))
    for typeimport in typeImports {
        index := find_module_index(imports, typeimport.from.value)
        if index == -1 {
            return nil, false
        }
        append_u32(&result, cast(u32)index)
        append_string(&result, typeimport.item.value)
    }
    append_u32(&result, cast(u32)len(typeDefinitions))
    for typedef in typeDefinitions {
        append_string(&result, typedef.name.value) 
    }
    append_u32(&result, cast(u32)len(typeDescriptors))
    append_type_descriptors(&result, typeDescriptors)
    fieldCount := 0
    for t in typeDefinitions {
        fieldCount += len(t.fields)
    }
    append_u32(&result, cast(u32)fieldCount)
    for t, i in typeDefinitions {
        for field in t.fields {
            append_u32(&result, cast(u32)i)
            append_string(&result, field.name.value)
            append_u32(&result, cast(u32)typeDescriptors[field.type.value].first)
        }
    }
    append_u32(&result, cast(u32)len(functionImports))
    for fnimport in functionImports {
        index := find_module_index(imports, fnimport.from.value)
        if index == -1 {
            return nil, false
        }
        append_u32(&result, cast(u32)index)
        append_string(&result, fnimport.item.value)
    }
    fndefsoffsets := make(map[string]pvm.Tuple(int, int))
    append_u32(&result, cast(u32)len(functionDefinitions));
    for fndef in functionDefinitions {
        append_string(&result, fndef.name.value)
        append_u32(&result, cast(u32)len(fndef.args))
        for arg in fndef.args {
            append_u32(&result, cast(u32)typeDescriptors[arg.type.value].first)
        }
        append_u32(&result, cast(u32)len(fndef.locals))
        for local in fndef.locals {
            append_u32(&result, cast(u32)typeDescriptors[local.type.value].first)
        }
        append_u32(&result, cast(u32)typeDescriptors[fndef.returnType.value].first)
        start := len(result)
        append_u32(&result, 0)
        length := len(result)
        append_u32(&result, 0)
        fndefsoffsets[fndef.name.value] = pvm.tuple(start, length)
    }
    append_u32(&result, cast(u32)len(strings))
    for str in strings {
        arr := make([]u16, len(str))
        defer delete(arr)
        utf16.encode_string(arr, str)
        for b in arr {
            append_u16(&result, b)
        }
        append_u16(&result, 0)
    }

    for mod in program.imports {
        _, err := pvm.load_module(&vm, mod.item.value) 
        if _, ok := err.(pvm.None); !ok {
            fmt.println("WARNING: Failed to load module", mod.item.value)
        }
    }
    for i in 0..<len(functionDefinitions) {
        fn := &functionDefinitions[i]
        compile_body(program, fn, &result, fndefsoffsets[fn.name.value])
    }
    return result[:], true
}
append_type_descriptors :: proc(bytes: ^[dynamic]u8, descriptors: map[string]pvm.Tuple(int, [dynamic]u8)) {
    descr := make([dynamic]pvm.Tuple(int, [dynamic]u8, len(descriptors)))
    for _, v in descriptors {
        append(&descr, v)
    }
    slice.sort_by_key(descr[:], proc(d: pvm.Tuple(int, [dynamic]u8)) -> int { return d.first })
    for desc in descr {
        append_bytes(bytes, desc.second)
    }
}
parse_error :: proc(str:string, token: Token) {
    fmt.printf("ERROR: %v at %v:%v\n", str, token.line, token.col)
    os.exit(1)
}
compile_body :: proc(using program: ^Program, function: ^Function, bytes: ^[dynamic]u8, offsets: pvm.Tuple(int, int)) {
    fmt.println("Compiling", function.name.value)
    start := len(bytes)
    labels := make(map[string]int)
    labelplaces := make([dynamic]pvm.Tuple(string, int))
    instrcount := 0
    for instruction in function.body {
        opcode, ok := instructions[instruction.opcode.value]
        if ok {
            switch opcode {
                case .SetField, .GetField, .GetFieldRef:
                    append(bytes, cast(u8)opcode)
                    switch in instruction.operand {
                        case FieldOperand:
                            type: Type = {}
                            typeindex := -1
                            for t, index in program.typeDefinitions {
                                if t.name.value == instruction.operand.(FieldOperand).type {
                                    type = t
                                    typeindex = index + len(program.typeImports)
                                    break
                                }
                            }
                            if typeindex == -1 {
                                importedType := -1
                                for t, index in program.typeImports {
                                    if t.item.value == instruction.operand.(FieldOperand).type {
                                        importedType = index
                                        break
                                    }
                                }
                                if importedType == -1 {
                                    parse_error("Unknown type", instruction.operand_token)
                                }
                                t := program.typeImports[importedType]
                                module, ok := vm.modules[t.from.value]
                                if !ok {
                                    parse_error("Unknown type", instruction.operand_token)
                                }
                                vmtype, _ := module.types[t.item.value]
                                if vmtype == nil {
                                    parse_error("Unknown type", instruction.operand_token)
                                }
                                fieldindex := -1
                                
                                for fld, index in vmtype.(pvm.CustomType).fields {
                                    if fld.name == instruction.operand.(FieldOperand).field{
                                        fieldindex = index 
                                        break
                                    }
                                }
                                if fieldindex == -1 {
                                    parse_error("Unknown field", instruction.operand_token);
                                }
                                append_u32(bytes, cast(u32)fieldindex)
                            }
                            else {
                                ok = false
                                for fld, index in type.fields {
                                    if fld.name.value == instruction.operand.(FieldOperand).field {
                                        append_u32(bytes, cast(u32)index)
                                        ok = true
                                        break
                                    }
                                }
                                if !ok {
                                    parse_error("Unknown field", instruction.operand_token)
                                }
                            }
                        case Integer:
                            local, ok := strconv.parse_u64(instruction.operand.(Integer).value)
                            if !ok {
                                parse_error("Bad integer", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)local)
                        case None, Id, TypeDescriptor, CharOperand, StringOperand: 
                            parse_error("Expected integer or field", instruction.operand_token)
                    }
                case .PushChar:
                    append(bytes, cast(u8)opcode)
                    if v, ok := instruction.operand.(CharOperand); !ok {
                        parse_error("Expected char", instruction.operand_token)
                    } 
                    arr := make([]u16, 1)
                    defer delete(arr)
                    utf16.encode_string(arr, instruction.operand_token.value)
                    append(bytes, cast(u8)(arr[0]))
                    append(bytes, cast(u8)(arr[0] << 8))
                case .PushI64:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_i64(instruction.operand.(Integer).value)
                    append_u64(bytes, transmute(u64)val)
                case .PushU64:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_u64(instruction.operand.(Integer).value)
                    append_u64(bytes, val)
                case .PushI32:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_i64(instruction.operand.(Integer).value)
                    append_u32(bytes, transmute(u32)cast(i32)val)
                case .PushU32:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_u64(instruction.operand.(Integer).value)
                    append_u32(bytes, cast(u32)val)
                case .PushI16:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_i64(instruction.operand.(Integer).value)
                    append_u16(bytes, transmute(u16)cast(i16)val)
                case .PushU16:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_u64(instruction.operand.(Integer).value)
                    append_u16(bytes, cast(u16)val)
                case .PushI8:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_i64(instruction.operand.(Integer).value)
                    append(bytes, transmute(u8)cast(i8)val)
                case .PushU8:
                    append(bytes, cast(u8)opcode)
                    val, _ := strconv.parse_u64(instruction.operand.(Integer).value)
                    append(bytes, cast(u8)val)
                case .SetLocal, .RefLocal, .PushLocal:
                    append(bytes, cast(u8)opcode)
                    op := instruction.operand
                    switch in op {
                        case Integer:
                            local, ok := strconv.parse_u64(op.(Integer).value)
                            if !ok {
                                parse_error("Bad integer", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)local)
                        case Id:
                            index := -1
                            for v, i in function.args {
                                if v.name.value == op.(Id).value {
                                    index = i
                                    break
                                }
                            }
                            if index == -1 {
                                for v, i in function.locals {
                                    if v.name.value == op.(Id).value {
                                        index = i + len(function.args)
                                        break
                                    }
                                }
                                if index == -1 {
                                    parse_error("Unknown variable", instruction.operand_token)
                                }
                            }
                            append_u32(bytes, cast(u32)index)
                        case None, TypeDescriptor, FieldOperand, CharOperand, StringOperand:
                            parse_error("Expected variable or integer", instruction.operand_token)
                    }
                case .Jmp:
                    fallthrough
                case .Jtrue:
                    append(bytes, cast(u8)opcode)
                    op := instruction.operand
                    switch in op {
                        case Integer:
                            local, ok := strconv.parse_u64(op.(Integer).value)
                            if !ok {
                                parse_error("Bad integer", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)local)
                        case Id:
                            if lbl, found := labels[op.(Id).value]; found {
                                append_u32(bytes, cast(u32)lbl)
                            }
                            else {
                                append(&labelplaces, pvm.tuple(op.(Id).value, len(bytes)))
                                append_u32(bytes, 0)
                            }
                            case None, TypeDescriptor, FieldOperand, CharOperand, StringOperand:
                            parse_error("Expected label or integer", instruction.operand_token)
                    }
                case    .Add,
                        .Sub,
                        .Div,
                        .Mul,
                        .Pop,
                        .Ret,
                        .GT,
                        .LT,
                        .Not,
                        .EQ,
                        .PushTrue,
                        .StoreRef,
                        .Deref,
                        .PushFalse,
                        .Neg,
                        .Dup, 
                        .GetIndex,
                        .GetIndexRef,
                        .SetIndex,
                        .ToRawPtr,
                        .PushNull, .GetLength,
                        .Box,
                        .Unbox:
                    append(bytes, cast(u8)opcode)
                case .Call:
                    append(bytes, cast(u8)opcode)
                    op := instruction.operand

                    switch in op {
                        case Integer:
                            local, ok := strconv.parse_u64(op.(Integer).value)
                            if !ok {
                                parse_error("Bad integer", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)local)
                        case Id:
                            index := -1
                            for f, i in functionImports {
                                if f.item.value == op.(Id).value {
                                    index = i 
                                    break
                                }
                            }
                            if index == -1 {
                                for f, i in functionDefinitions {
                                    if f.name.value == op.(Id).value {
                                        index = i + len(functionImports)
                                        break
                                    }
                                }
                                if index == -1 {
                                    parse_error("Unknown function", instruction.operand_token)
                                }
                            }
                            append_u32(bytes, cast(u32)index)
                        case None, TypeDescriptor, FieldOperand, CharOperand, StringOperand:
                            parse_error("Expected function or integer", instruction.operand_token)
                    } 
                case .NewObj, .IsInstanceOf, .UnboxAs, .Cast, .Conv:
                    append(bytes, cast(u8)opcode)
                    switch in instruction.operand {
                        case TypeDescriptor, Id:
                            value := ""
                            id, isid := instruction.operand.(Id)
                            if isid {
                                value = id.value
                            }
                            else {
                                value = instruction.operand.(TypeDescriptor).value
                            }
                            type, ok := program.typeDescriptors[value] 
                            if !ok {
                                parse_error("Unknown type", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)type.first)
                        case Integer:
                            local, ok := strconv.parse_u64(instruction.operand.(Integer).value)
                            if !ok {
                                parse_error("Bad integer", instruction.operand_token)
                            }
                            append_u32(bytes, cast(u32)local)
                        case None, FieldOperand, CharOperand, StringOperand:
                            parse_error("Expected type of integer", instruction.operand_token)
                            
                    } 
                case .PushString:
                    switch in instruction.operand {
                        case StringOperand:
                            str, _ := program.strings_map[instruction.operand.(StringOperand).value]
                            append(bytes, cast(u8)opcode)

                            append_u32(bytes, cast(u32)str)
                        case None, FieldOperand, CharOperand, Integer, Id, TypeDescriptor:
                            parse_error("Expected string", instruction.operand_token)
                    }
                case .PushF64, .PushF32:
                    fmt.println("oopsie", opcode)
                    panic("")
            }
            instrcount += 1
        }
        else {
            if _, labelFound := labels[instruction.opcode.value]; labelFound {
                parse_error("Label redefinition", instruction.opcode)
            }
            else {
                labels[instruction.opcode.value] = instrcount
            }
        }
    }
    for tuple in labelplaces {
        lbl, ok := labels[tuple.first]
        if !ok {
            parse_error("Unknown label", {})
        }
        bytes[tuple.second] = cast(u8)lbl
        bytes[tuple.second + 1] = cast(u8)(lbl >> 8)
        bytes[tuple.second + 2] = cast(u8)(lbl >> 16)
        bytes[tuple.second + 3] = cast(u8)(lbl >> 24)
    }
    length := len(bytes) - start
    bytes[offsets.first] = cast(u8)start
    bytes[offsets.first + 1] = cast(u8)(start >> 8)
    bytes[offsets.first + 2] = cast(u8)(start >> 16)
    bytes[offsets.first + 3] = cast(u8)(start >> 24)
    bytes[offsets.second] = cast(u8)length
    bytes[offsets.second + 1] = cast(u8)(length >> 8)
    bytes[offsets.second + 2] = cast(u8)(length >> 16)
    bytes[offsets.second + 3] = cast(u8)(length >> 24)
}
append_bytes :: proc(bytes: ^[dynamic]u8, value: [dynamic]u8) {
    for v in value {
        append(bytes, v)
    }
}
find_module_index :: proc(modules: [dynamic]Import, name: string) -> int {
    for mod, i in modules {
        if mod.item.value == name {
            return i
        }
    }
    return -1
}
append_string :: proc(bytes: ^[dynamic]u8, value: string) {
    for b in value {
        append(bytes, cast(u8)b)
    }
    append(bytes, 0)
}
append_u16 :: proc(bytes: ^[dynamic]u8, value: u16) {
    append(bytes, cast(u8)(value))
    append(bytes, cast(u8)(value >> 8))
}
append_u32 :: proc(bytes: ^[dynamic]u8, value: u32) {
    append(bytes, cast(u8)(value))
    append(bytes, cast(u8)(value >> 8))
    append(bytes, cast(u8)(value >> 16))
    append(bytes, cast(u8)(value >> 24))
}
append_u64 :: proc(bytes: ^[dynamic]u8, value: u64) {
    append(bytes, cast(u8)(value & 0xff))
    append(bytes, cast(u8)((value >> 8) & 0xff))
    append(bytes, cast(u8)((value >> 16) & 0xff))
    append(bytes, cast(u8)((value >> 24) & 0xff))
    append(bytes, cast(u8)((value >> 32) & 0xff))
    append(bytes, cast(u8)((value >> 40) & 0xff))
    append(bytes, cast(u8)((value >> 48) & 0xff))
    append(bytes, cast(u8)((value >> 56) & 0xff))
}
primitives := map[string]pvm.PrimitiveType {
    "i64" = pvm.PrimitiveType.I64,
    "u64" = pvm.PrimitiveType.U64,
    "i32" = pvm.PrimitiveType.I32,
    "u32" = pvm.PrimitiveType.U32,
    "i16" = pvm.PrimitiveType.I16,
    "u16" = pvm.PrimitiveType.U16,
    "i8" = pvm.PrimitiveType.I8,
    "u8" = pvm.PrimitiveType.U8,
    "f64" = pvm.PrimitiveType.F64,
    "f32" = pvm.PrimitiveType.F32,
    "any" = pvm.PrimitiveType.Any,
    "char" = pvm.PrimitiveType.Char,
    "string" = pvm.PrimitiveType.String,
    "void" = pvm.PrimitiveType.Void,
    "bool" = pvm.PrimitiveType.Boolean,
}
create_type_descriptor :: proc(using program: ^Program, descriptor: string) -> ([dynamic]u8, bool) {
    res := make([dynamic]u8)
    for char, i in descriptor {
        if char == '*' {
            append(&res, 1)
        }
        else if char == '$' {
            append(&res, 2)
        }
        else if char == '&' {
            append(&res, 3)
        }
        else {
            typename := descriptor[i:]
            if primitive, found := primitives[typename]; found {
                append(&res, 0)
                append(&res, cast(u8)primitive)
            } 
            else {
                foundindex := -1
                for typeimp, index in typeImports {
                    if typeimp.item.value == typename {
                        foundindex = index
                        break
                    }
                } 
                if foundindex == -1 {
                    for type, index in typeDefinitions {
                        if type.name.value == typename {
                            foundindex = index + len(typeImports)
                            break
                        }
                    }
                }
                if foundindex != -1 {
                    append(&res, 4)
                    append_u32(&res, cast(u32)foundindex)
                }
                else {
                    delete(res)
                    return nil, false
                }
            }
            break
        }
    }
    return res, true
}
main :: proc() {
    tracking := mem.Tracking_Allocator {};
    mem.tracking_allocator_init(&tracking, context.allocator);
    context.allocator = mem.tracking_allocator(&tracking);
    pvm.set_formatter();
    before := len(tracking.allocation_map)
    {
    if len(os.args) != 2 {
        return
    }
    str, ok := read_file_to_string(os.args[1])
    defer delete(str)
    if ok { 
        tokenizer := Tokenizer {}
        tokenizer_init(&tokenizer)
        tokens := tokenize(&tokenizer, str)
//         for tok in tokens {
//             fmt.println(tok);
//         }
        defer {
            for t in tokens {
                delete(t.value)
            }
            delete(tokens)
        }
        parser := Parser{}
        parser_init(&parser)
        program := Program{}
        program, ok = parse(&parser, tokens)
        defer {
            for _, desc in program.typeDescriptors {
                delete(desc.second)
            }

            delete(program.imports)
            delete(program.typeImports)
            delete(program.functionImports)
            delete(program.typeDefinitions)
            delete(program.functionDefinitions)
            delete(program.typeDescriptors)
        }
        res, compiled := compile(&program, tokens)
        if compiled && ok {
            fmt.println("success")
            os.write_entire_file(strings.concatenate([]string{program.name.value, ".mod"}), res)
        }
    }
    }
    after := len(tracking.allocation_map)
    fmt.println(before, after)
}
