import Foundation

public enum LanguageCatalog {
    private enum Pattern {
        static let doubleQuoted = #""(?:[^"\\\n]|\\.)*""#
        static let singleQuoted = #"'(?:[^'\\\n]|\\.)*'"#
        static let backtick = #"`(?:[^`\\]|\\.)*`"#
        static let tripleDoubleQuoted = #""""[\s\S]*?""""#
        static let slashLineComment = #"//.*$"#
        static let blockComment = #"/\*[\s\S]*?\*/"#
        static let hashLineComment = #"#.*$"#
        static let number = #"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)[a-zA-Z]{0,3}\b"#
        static let functionCall = #"\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\()"#
        static let capitalizedType = #"\b[A-Z][A-Za-z0-9_]*\b"#
    }

    private static let cStyleComments = CommentSyntax(lineComment: "//", blockComment: .init(start: "/*", end: "*/"))
    private static let hashComments = CommentSyntax(lineComment: "#")

    public static let swift = Language(
        id: "swift",
        name: "Swift",
        fileExtensions: ["swift"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.tripleDoubleQuoted, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"@[A-Za-z_]\w*"#, .attribute),
            HighlightRule(#"#[A-Za-z_]\w*"#, .directive),
            .words([
                "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
                "convenience", "default", "defer", "deinit", "didSet", "do", "dynamic", "else", "enum", "extension",
                "fallthrough", "fileprivate", "final", "for", "func", "get", "guard", "if", "import", "in", "indirect",
                "init", "inout", "internal", "is", "isolated", "lazy", "let", "macro", "mutating", "nonisolated",
                "nonmutating", "open", "operator", "optional", "override", "package", "precedencegroup", "private",
                "protocol", "public", "repeat", "required", "rethrows", "return", "set", "some", "static", "struct",
                "subscript", "super", "switch", "throw", "throws", "try", "typealias", "var", "weak", "unowned",
                "where", "while", "willSet", "consume", "borrowing", "consuming", "sending"
            ], .keyword),
            .words(["true", "false", "nil", "self", "Self"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    private static let cKeywords = [
        "auto", "break", "case", "const", "continue", "default", "do", "else", "enum", "extern", "for", "goto", "if",
        "inline", "register", "restrict", "return", "sizeof", "static", "struct", "switch", "typedef", "union",
        "volatile", "while", "_Bool", "_Atomic", "_Generic", "_Noreturn", "_Static_assert", "_Thread_local"
    ]
    private static let cTypes = [
        "char", "double", "float", "int", "long", "short", "signed", "unsigned", "void", "bool", "size_t",
        "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "ptrdiff_t"
    ]

    public static let c = Language(
        id: "c",
        name: "C",
        fileExtensions: ["c", "h"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"^\s*#\s*[A-Za-z_]\w*"#, .directive),
            .words(cKeywords, .keyword),
            .words(cTypes, .type),
            .words(["NULL", "true", "false"], .constant),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let cpp = Language(
        id: "cpp",
        name: "C++",
        fileExtensions: ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "ino"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(#"R"\(([\s\S]*?)\)""#, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"^\s*#\s*[A-Za-z_]\w*"#, .directive),
            .words(cKeywords + [
                "alignas", "alignof", "catch", "class", "concept", "consteval", "constexpr", "constinit", "co_await",
                "co_return", "co_yield", "decltype", "delete", "explicit", "export", "friend", "mutable", "namespace",
                "new", "noexcept", "operator", "private", "protected", "public", "requires", "static_assert",
                "template", "this", "throw", "try", "typeid", "typename", "using", "virtual", "override", "final"
            ], .keyword),
            .words(cTypes + ["wchar_t", "char8_t", "char16_t", "char32_t", "auto", "string", "vector", "map"], .type),
            .words(["nullptr", "NULL", "true", "false"], .constant),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let objectiveC = Language(
        id: "objectivec",
        name: "Objective-C",
        fileExtensions: ["m", "mm"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(#"@?"(?:[^"\\\n]|\\.)*""#, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"^\s*#\s*[A-Za-z_]\w*"#, .directive),
            HighlightRule(#"@[A-Za-z_]\w*"#, .keyword),
            .words(cKeywords + ["self", "super", "id", "instancetype", "nonatomic", "atomic", "strong", "weak",
                                "copy", "assign", "readonly", "readwrite", "nullable", "nonnull", "__block"], .keyword),
            .words(cTypes + ["BOOL", "NSInteger", "NSUInteger", "CGFloat", "SEL", "Class"], .type),
            .words(["nil", "Nil", "YES", "NO", "NULL", "true", "false"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let csharp = Language(
        id: "csharp",
        name: "C#",
        fileExtensions: ["cs", "csx"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(#"@"(?:[^"]|"")*""#, .string),
            HighlightRule(#"\$?"(?:[^"\\\n]|\\.)*""#, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"^\s*#\s*[A-Za-z_]\w*"#, .directive),
            HighlightRule(#"\[[A-Z]\w*(?:\(.*?\))?\]"#, .attribute),
            .words([
                "abstract", "as", "async", "await", "base", "break", "case", "catch", "checked", "class", "const",
                "continue", "default", "delegate", "do", "else", "enum", "event", "explicit", "extern", "finally",
                "fixed", "for", "foreach", "get", "goto", "if", "implicit", "in", "init", "interface", "internal", "is",
                "lock", "namespace", "new", "operator", "out", "override", "params", "partial", "private", "protected",
                "public", "readonly", "record", "ref", "required", "return", "sealed", "set", "sizeof", "stackalloc",
                "static", "struct", "switch", "this", "throw", "try", "typeof", "unchecked", "unsafe", "using", "var",
                "virtual", "void", "volatile", "when", "where", "while", "yield"
            ], .keyword),
            .words(["bool", "byte", "char", "decimal", "double", "dynamic", "float", "int", "long", "object", "sbyte",
                    "short", "string", "uint", "ulong", "ushort"], .type),
            .words(["true", "false", "null"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let java = Language(
        id: "java",
        name: "Java",
        fileExtensions: ["java"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.tripleDoubleQuoted, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"@[A-Za-z_]\w*"#, .attribute),
            .words([
                "abstract", "assert", "break", "case", "catch", "class", "const", "continue", "default", "do", "else",
                "enum", "extends", "final", "finally", "for", "goto", "if", "implements", "import", "instanceof",
                "interface", "native", "new", "non-sealed", "package", "permits", "private", "protected", "public",
                "record", "return", "sealed", "static", "strictfp", "super", "switch", "synchronized", "this", "throw",
                "throws", "transient", "try", "var", "volatile", "while", "yield"
            ], .keyword),
            .words(["boolean", "byte", "char", "double", "float", "int", "long", "short", "void"], .type),
            .words(["true", "false", "null"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let kotlin = Language(
        id: "kotlin",
        name: "Kotlin",
        fileExtensions: ["kt", "kts"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.tripleDoubleQuoted, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"@[A-Za-z_]\w*"#, .attribute),
            .words([
                "abstract", "annotation", "as", "break", "by", "catch", "class", "companion", "const", "constructor",
                "continue", "crossinline", "data", "do", "else", "enum", "external", "final", "finally", "for", "fun",
                "get", "if", "import", "in", "infix", "init", "inline", "inner", "interface", "internal", "is",
                "lateinit", "noinline", "object", "open", "operator", "out", "override", "package", "private",
                "protected", "public", "reified", "return", "sealed", "set", "super", "suspend", "this", "throw",
                "try", "typealias", "val", "value", "var", "vararg", "when", "where", "while"
            ], .keyword),
            .words(["true", "false", "null"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let go = Language(
        id: "go",
        name: "Go",
        fileExtensions: ["go"],
        fileNames: ["go.mod", "go.sum"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.backtick, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            .words([
                "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func",
                "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct",
                "switch", "type", "var"
            ], .keyword),
            .words(["bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16",
                    "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "any"],
                   .type),
            .words(["true", "false", "nil", "iota"], .constant),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let rust = Language(
        id: "rust",
        name: "Rust",
        fileExtensions: ["rs"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(##"r#*"[\s\S]*?"#*"##, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"'(?:[^'\\\n]|\\.)'"#, .string),
            HighlightRule(#"#!?\[[^\]\n]*\]"#, .attribute),
            HighlightRule(#"\b[a-z_]\w*!"#, .directive),
            .words([
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "fn",
                "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
                "self", "static", "struct", "super", "trait", "type", "unsafe", "use", "where", "while", "yield"
            ], .keyword),
            .words(["bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128", "isize", "str", "u8", "u16", "u32",
                    "u64", "u128", "usize", "Self"], .type),
            .words(["true", "false", "None", "Some", "Ok", "Err"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    private static let javaScriptKeywords = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
        "do", "else", "export", "extends", "finally", "for", "from", "function", "get", "if", "import", "in",
        "instanceof", "let", "new", "of", "return", "set", "static", "super", "switch", "this", "throw", "try",
        "typeof", "var", "void", "while", "with", "yield"
    ]

    public static let javaScript = Language(
        id: "javascript",
        name: "JavaScript",
        fileExtensions: ["js", "mjs", "cjs", "jsx"],
        interpreters: ["node", "deno", "bun"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(Pattern.backtick, .string),
            .words(javaScriptKeywords, .keyword),
            .words(["true", "false", "null", "undefined", "NaN", "Infinity"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let typeScript = Language(
        id: "typescript",
        name: "TypeScript",
        fileExtensions: ["ts", "tsx", "mts", "cts"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(Pattern.backtick, .string),
            HighlightRule(#"@[A-Za-z_]\w*"#, .attribute),
            .words(javaScriptKeywords + [
                "abstract", "as", "declare", "enum", "implements", "interface", "keyof", "namespace", "private",
                "protected", "public", "readonly", "satisfies", "type", "infer", "is", "override"
            ], .keyword),
            .words(["any", "boolean", "never", "number", "object", "string", "symbol", "unknown", "bigint"], .type),
            .words(["true", "false", "null", "undefined", "NaN", "Infinity"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let python = Language(
        id: "python",
        name: "Python",
        fileExtensions: ["py", "pyw", "pyi"],
        interpreters: ["python", "pypy"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(#"[rRbBuUfF]{0,2}"""[\s\S]*?""""#, .string),
            HighlightRule(#"[rRbBuUfF]{0,2}'''[\s\S]*?'''"#, .string),
            HighlightRule(#"[rRbBuUfF]{0,2}"(?:[^"\\\n]|\\.)*""#, .string),
            HighlightRule(#"[rRbBuUfF]{0,2}'(?:[^'\\\n]|\\.)*'"#, .string),
            HighlightRule(#"^\s*@[\w.]+"#, .attribute),
            .words([
                "and", "as", "assert", "async", "await", "break", "case", "class", "continue", "def", "del", "elif",
                "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "match",
                "nonlocal", "not", "or", "pass", "raise", "return", "try", "type", "while", "with", "yield"
            ], .keyword),
            .words(["True", "False", "None", "self", "cls"], .constant),
            .words(["int", "float", "str", "bool", "list", "dict", "set", "tuple", "bytes", "object"], .type),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let ruby = Language(
        id: "ruby",
        name: "Ruby",
        fileExtensions: ["rb", "rake", "gemspec", "ru"],
        fileNames: ["Gemfile", "Rakefile", "Podfile", "Fastfile", "Brewfile"],
        interpreters: ["ruby"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(#"^=begin[\s\S]*?^=end"#, .comment),
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"(?<!:):[A-Za-z_]\w*[?!]?"#, .constant),
            HighlightRule(#"@{1,2}[A-Za-z_]\w*|\$[A-Za-z_]\w*"#, .variable),
            .words([
                "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else",
                "elsif", "end", "ensure", "for", "if", "in", "module", "next", "not", "or", "redo", "rescue", "retry",
                "return", "self", "super", "then", "undef", "unless", "until", "when", "while", "yield", "require",
                "attr_reader", "attr_writer", "attr_accessor", "private", "protected", "public"
            ], .keyword),
            .words(["true", "false", "nil"], .constant),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let php = Language(
        id: "php",
        name: "PHP",
        fileExtensions: ["php", "phtml", "php8"],
        interpreters: ["php"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(#"#(?!\[).*$"#, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"<\?(?:php|=)?|\?>"#, .directive),
            HighlightRule(#"#\[[^\]\n]*\]"#, .attribute),
            HighlightRule(#"\$[A-Za-z_]\w*"#, .variable),
            .words([
                "abstract", "and", "as", "break", "callable", "case", "catch", "class", "clone", "const", "continue",
                "declare", "default", "do", "echo", "else", "elseif", "empty", "enddeclare", "endfor", "endforeach",
                "endif", "endswitch", "endwhile", "enum", "extends", "final", "finally", "fn", "for", "foreach",
                "function", "global", "if", "implements", "include", "include_once", "instanceof", "insteadof",
                "interface", "isset", "list", "match", "namespace", "new", "or", "print", "private", "protected",
                "public", "readonly", "require", "require_once", "return", "static", "switch", "throw", "trait", "try",
                "unset", "use", "var", "while", "xor", "yield"
            ], .keyword, caseInsensitive: true),
            .words(["true", "false", "null"], .constant, caseInsensitive: true),
            HighlightRule(Pattern.capitalizedType, .type),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let shell = Language(
        id: "shell",
        name: "Shell",
        fileExtensions: ["sh", "bash", "zsh", "ksh", "command", "fish"],
        fileNames: [".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".profile", ".zshenv"],
        interpreters: ["sh", "bash", "zsh", "ksh", "dash", "fish"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(#"(?:^|(?<=\s))#.*$"#, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"'[^'\n]*'"#, .string),
            HighlightRule(#"\$\{[^}\n]*\}|\$\([^)\n]*\)|\$[A-Za-z_]\w*|\$[0-9#?@*$!-]"#, .variable),
            .words([
                "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in",
                "function", "select", "return", "exit", "break", "continue", "local", "export", "readonly", "declare",
                "source", "alias", "unset", "shift", "trap", "eval", "exec"
            ], .keyword),
            .words(["echo", "printf", "cd", "pwd", "test", "read", "set", "true", "false"], .function),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let powerShell = Language(
        id: "powershell",
        name: "PowerShell",
        fileExtensions: ["ps1", "psm1", "psd1"],
        interpreters: ["pwsh", "powershell"],
        commentSyntax: CommentSyntax(lineComment: "#", blockComment: .init(start: "<#", end: "#>")),
        rules: [
            HighlightRule(#"<#[\s\S]*?#>"#, .comment),
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"'[^'\n]*'"#, .string),
            HighlightRule(#"\$[\w:]+"#, .variable),
            .words([
                "begin", "break", "catch", "class", "continue", "data", "do", "dynamicparam", "else", "elseif", "end",
                "enum", "exit", "filter", "finally", "for", "foreach", "function", "if", "in", "param", "process",
                "return", "switch", "throw", "trap", "try", "until", "using", "while"
            ], .keyword, caseInsensitive: true),
            HighlightRule(#"\b[A-Z][a-z]+-[A-Z]\w+\b"#, .function),
            HighlightRule(#"(?<=\s)-[A-Za-z]+\b"#, .attribute),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let batch = Language(
        id: "batch",
        name: "Batch",
        fileExtensions: ["bat", "cmd"],
        commentSyntax: CommentSyntax(lineComment: "REM"),
        rules: [
            HighlightRule(#"(?i:^\s*@?rem\b.*$)|^\s*::.*$"#, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"^:[A-Za-z_]\w*"#, .directive),
            HighlightRule(#"%[\w~:]+%|%%[A-Za-z]|%~?[0-9*]|![\w]+!"#, .variable),
            .words([
                "call", "cd", "chdir", "cls", "copy", "del", "dir", "echo", "else", "endlocal", "errorlevel", "exist",
                "exit", "for", "goto", "if", "in", "md", "mkdir", "move", "not", "pause", "popd", "pushd", "rd",
                "ren", "rmdir", "set", "setlocal", "shift", "start", "title", "type", "do", "defined", "equ", "neq",
                "lss", "leq", "gtr", "geq", "off", "on"
            ], .keyword, caseInsensitive: true),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let sql = Language(
        id: "sql",
        name: "SQL",
        fileExtensions: ["sql", "ddl", "dml"],
        commentSyntax: CommentSyntax(lineComment: "--", blockComment: .init(start: "/*", end: "*/")),
        rules: [
            HighlightRule(#"--.*$"#, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(#"'(?:[^']|'')*'"#, .string),
            HighlightRule(#""[^"\n]*"|`[^`\n]*`"#, .variable),
            .words([
                "add", "all", "alter", "and", "as", "asc", "begin", "between", "by", "case", "check", "column", "commit",
                "constraint", "create", "cross", "database", "default", "delete", "desc", "distinct", "drop", "else",
                "end", "exists", "foreign", "from", "full", "group", "having", "if", "in", "index", "inner", "insert",
                "into", "is", "join", "key", "left", "like", "limit", "not", "offset", "on", "or", "order", "outer",
                "primary", "references", "returning", "right", "rollback", "select", "set", "table", "then",
                "transaction", "trigger", "truncate", "union", "unique", "update", "values", "view", "when", "where",
                "with"
            ], .keyword, caseInsensitive: true),
            .words(["bigint", "blob", "boolean", "char", "date", "datetime", "decimal", "double", "float", "int",
                    "integer", "json", "numeric", "real", "serial", "smallint", "text", "time", "timestamp", "uuid",
                    "varchar"], .type, caseInsensitive: true),
            .words(["null", "true", "false"], .constant, caseInsensitive: true),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let html = Language(
        id: "html",
        name: "HTML",
        fileExtensions: ["html", "htm", "xhtml", "shtml"],
        commentSyntax: CommentSyntax(blockComment: .init(start: "<!--", end: "-->")),
        rules: [
            HighlightRule(#"<!--[\s\S]*?-->"#, .comment),
            HighlightRule(#"(?i:<!doctype[^>]*>)"#, .directive),
            HighlightRule(#"</?[A-Za-z][\w:-]*|/?>"#, .tag),
            HighlightRule(#"\b[A-Za-z_:][\w:.-]*(?=\s*=)"#, .attribute),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"&(?:#\d+|#x[0-9a-fA-F]+|\w+);"#, .constant)
        ]
    )

    public static let xml = Language(
        id: "xml",
        name: "XML",
        fileExtensions: ["xml", "plist", "svg", "xsd", "xsl", "xslt", "storyboard", "xib", "csproj", "resx", "rss", "atom"],
        commentSyntax: CommentSyntax(blockComment: .init(start: "<!--", end: "-->")),
        rules: [
            HighlightRule(#"<!--[\s\S]*?-->"#, .comment),
            HighlightRule(#"<!\[CDATA\[[\s\S]*?\]\]>"#, .string),
            HighlightRule(#"<\?[\s\S]*?\?>|<![A-Z][^>]*>"#, .directive),
            HighlightRule(#"</?[A-Za-z_][\w:.-]*|/?>"#, .tag),
            HighlightRule(#"\b[A-Za-z_:][\w:.-]*(?=\s*=)"#, .attribute),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"&(?:#\d+|#x[0-9a-fA-F]+|\w+);"#, .constant)
        ]
    )

    private static let cssRules: [HighlightRule] = [
        HighlightRule(Pattern.blockComment, .comment),
        HighlightRule(Pattern.doubleQuoted, .string),
        HighlightRule(Pattern.singleQuoted, .string),
        HighlightRule(#"@[\w-]+"#, .directive),
        HighlightRule(#"#[0-9a-fA-F]{3,8}\b"#, .constant),
        HighlightRule(#"!important\b"#, .keyword),
        HighlightRule(#"(?<![\w-])-?\d*\.?\d+(?:px|em|rem|%|vh|vw|vmin|vmax|ch|ex|pt|cm|mm|in|s|ms|deg|rad|turn|fr|dpi)?\b"#, .number),
        HighlightRule(#"[\w-]+(?=\()"#, .function),
        HighlightRule(#"(?<=[{;\s])[a-z-]+(?=\s*:(?!:))"#, .attribute),
        HighlightRule(#"[.#][A-Za-z_-][\w-]*"#, .tag),
        HighlightRule(#"\$[\w-]+|--[\w-]+"#, .variable)
    ]

    public static let css = Language(
        id: "css",
        name: "CSS",
        fileExtensions: ["css"],
        commentSyntax: CommentSyntax(blockComment: .init(start: "/*", end: "*/")),
        rules: cssRules
    )

    public static let scss = Language(
        id: "scss",
        name: "SCSS",
        fileExtensions: ["scss", "sass", "less"],
        commentSyntax: cStyleComments,
        rules: [HighlightRule(Pattern.slashLineComment, .comment)] + cssRules
    )

    public static let json = Language(
        id: "json",
        name: "JSON",
        fileExtensions: ["json", "jsonc", "json5", "geojson", "webmanifest", "jsonl", "ndjson"],
        fileNames: [".prettierrc", ".eslintrc", ".babelrc"],
        commentSyntax: cStyleComments,
        rules: [
            HighlightRule(Pattern.slashLineComment, .comment),
            HighlightRule(Pattern.blockComment, .comment),
            HighlightRule(#""(?:[^"\\\n]|\\.)*"(?=\s*:)"#, .attribute),
            HighlightRule(Pattern.doubleQuoted, .string),
            .words(["true", "false", "null"], .constant),
            HighlightRule(#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number)
        ]
    )

    public static let yaml = Language(
        id: "yaml",
        name: "YAML",
        fileExtensions: ["yml", "yaml"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(#"(?:^|(?<=\s))#.*$"#, .comment),
            HighlightRule(#"^(?:---|\.\.\.)\s*$"#, .directive),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"^[ \t]*(?:-[ \t]+)?[^\s:#'"\-][^:#\n]*(?=:(?:\s|$))"#, .attribute),
            HighlightRule(#"[&*][A-Za-z0-9_-]+"#, .variable),
            HighlightRule(#"!![\w]+|![\w]+"#, .type),
            .words(["true", "false", "yes", "no", "on", "off", "null"], .constant, caseInsensitive: true),
            HighlightRule(#"(?<![\w.])-?\d+(?:\.\d+)?\b"#, .number)
        ]
    )

    public static let toml = Language(
        id: "toml",
        name: "TOML",
        fileExtensions: ["toml"],
        fileNames: ["Cargo.lock", "Pipfile"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(Pattern.tripleDoubleQuoted, .string),
            HighlightRule(#"'''[\s\S]*?'''"#, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(#"'[^'\n]*'"#, .string),
            HighlightRule(#"^\s*\[\[?[^\]\n]+\]\]?"#, .heading),
            HighlightRule(#"^\s*[\w.\-"']+(?=\s*=)"#, .attribute),
            .words(["true", "false", "inf", "nan"], .constant),
            HighlightRule(#"\b\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)?\b"#, .number),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let ini = Language(
        id: "ini",
        name: "INI",
        fileExtensions: ["ini", "cfg", "conf", "properties", "editorconfig", "env", "desktop", "reg"],
        fileNames: [".editorconfig", ".gitconfig", ".env", ".npmrc", ".gitattributes"],
        commentSyntax: CommentSyntax(lineComment: ";"),
        rules: [
            HighlightRule(#"^\s*[;#].*$"#, .comment),
            HighlightRule(#"^\s*\[[^\]\n]+\]"#, .heading),
            HighlightRule(#"^\s*[^=\s;#\[][^=\n]*?(?=\s*[=:])"#, .attribute),
            HighlightRule(Pattern.doubleQuoted, .string),
            .words(["true", "false", "yes", "no", "on", "off"], .constant, caseInsensitive: true),
            HighlightRule(#"(?<=[=:])\s*-?\d+(?:\.\d+)?\s*$"#, .number)
        ]
    )

    public static let markdown = Language(
        id: "markdown",
        name: "Markdown",
        fileExtensions: ["md", "markdown", "mdown", "mkd", "mdx"],
        fileNames: ["README", "CHANGELOG"],
        commentSyntax: CommentSyntax(blockComment: .init(start: "<!--", end: "-->")),
        rules: [
            HighlightRule(#"^```[\s\S]*?^```\s*$"#, .string),
            HighlightRule(#"<!--[\s\S]*?-->"#, .comment),
            HighlightRule(#"^#{1,6}\s.*$"#, .heading),
            HighlightRule(#"^.+\n(?:=+|-+)\s*$"#, .heading),
            HighlightRule(#"^>.*$"#, .comment),
            HighlightRule(#"`[^`\n]+`"#, .string),
            HighlightRule(#"!?\[[^\]\n]*\]\([^)\n]*\)|<https?://[^>\s]+>"#, .link),
            HighlightRule(#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, .emphasis),
            HighlightRule(#"(?<![*\w])\*[^*\n]+\*(?!\*)|(?<![_\w])_[^_\n]+_(?![_\w])"#, .emphasis),
            HighlightRule(#"^\s*(?:[-*+]|\d+[.)])(?=\s)"#, .keyword),
            HighlightRule(#"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$"#, .directive)
        ]
    )

    public static let makefile = Language(
        id: "makefile",
        name: "Makefile",
        fileExtensions: ["mk", "mak", "make"],
        fileNames: ["Makefile", "GNUmakefile", "makefile"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"\$\([^)\n]*\)|\$\{[^}\n]*\}|\$[@<^?*%+]"#, .variable),
            HighlightRule(#"^\s*(?:include|-include|ifeq|ifneq|ifdef|ifndef|else|endif|define|endef|export|override|vpath)\b"#, .keyword),
            HighlightRule(#"^[\w./%$()\- ]+(?=\s*::?(?!=))"#, .function),
            HighlightRule(#"^\s*[\w.]+(?=\s*[:+?]?=)"#, .attribute)
        ]
    )

    public static let dockerfile = Language(
        id: "dockerfile",
        name: "Dockerfile",
        fileExtensions: ["dockerfile"],
        fileNames: ["Dockerfile", "Containerfile"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(#"^\s*#.*$"#, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"(?i:^\s*(?:FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b)"#, .keyword),
            HighlightRule(#"(?i:\bAS\b)"#, .keyword),
            HighlightRule(#"\$\{[^}\n]*\}|\$[A-Za-z_]\w*"#, .variable),
            HighlightRule(#"(?<=\s)--[\w-]+"#, .attribute),
            HighlightRule(Pattern.number, .number)
        ]
    )

    public static let lua = Language(
        id: "lua",
        name: "Lua",
        fileExtensions: ["lua"],
        interpreters: ["lua", "luajit"],
        commentSyntax: CommentSyntax(lineComment: "--", blockComment: .init(start: "--[[", end: "]]")),
        rules: [
            HighlightRule(#"--\[\[[\s\S]*?\]\]|--\[=\[[\s\S]*?\]=\]"#, .comment),
            HighlightRule(#"--.*$"#, .comment),
            HighlightRule(#"\[\[[\s\S]*?\]\]|\[=\[[\s\S]*?\]=\]"#, .string),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            .words([
                "and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in", "local", "not",
                "or", "repeat", "return", "then", "until", "while"
            ], .keyword),
            .words(["true", "false", "nil", "self"], .constant),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let perl = Language(
        id: "perl",
        name: "Perl",
        fileExtensions: ["pl", "pm", "t", "pod"],
        interpreters: ["perl"],
        commentSyntax: hashComments,
        rules: [
            HighlightRule(#"^=[a-z][\s\S]*?^=cut"#, .comment),
            HighlightRule(Pattern.hashLineComment, .comment),
            HighlightRule(Pattern.doubleQuoted, .string),
            HighlightRule(Pattern.singleQuoted, .string),
            HighlightRule(#"[$@%][A-Za-z_][\w:]*|\$[0-9_&`'+!@/\\]"#, .variable),
            .words([
                "if", "elsif", "else", "unless", "while", "until", "for", "foreach", "do", "last", "next", "redo",
                "return", "sub", "my", "our", "local", "use", "no", "require", "package", "and", "or", "not", "eq",
                "ne", "lt", "gt", "le", "ge", "cmp", "print", "printf", "die", "warn"
            ], .keyword),
            HighlightRule(Pattern.number, .number),
            HighlightRule(Pattern.functionCall, .function)
        ]
    )

    public static let diff = Language(
        id: "diff",
        name: "Diff",
        fileExtensions: ["diff", "patch"],
        rules: [
            HighlightRule(#"^(?:diff|index|---|\+\+\+) .*$"#, .heading),
            HighlightRule(#"^@@.*$"#, .directive),
            HighlightRule(#"^\+.*$"#, .inserted),
            HighlightRule(#"^-.*$"#, .deleted)
        ]
    )

    /// All languages in menu order, starting with plain text.
    public static let all: [Language] = [
        .plainText, batch, c, cpp, csharp, css, diff, dockerfile, go, html, ini, java, javaScript, json, kotlin, lua,
        makefile, markdown, objectiveC, perl, php, powerShell, python, ruby, rust, scss, shell, sql, swift, toml,
        typeScript, xml, yaml
    ]
}
