// SwiftSource.swift — shared test support (v2.1 A7b, corrective 2).
//
// The harnesses that READ scene/node code (catalog, guard, redsmile, void)
// match assertions against CODE, never comments. Cutting each line at its
// first `//` is not enough: a `/* … */` block (nested, in Swift) can still hide
// or fake a call, and a `//` inside a string literal is not a comment. This is
// a small Swift lexer, sufficient for the app's source files:
//   • line comments, block comments and NESTED block comments are BLANKED:
//     every removed character becomes a space and newlines stay (corrective 4),
//     so adjacent tokens never fuse (`#if/**/false` reads `#if     false`,
//     never `#iffalse`) and every view is aligned character for character with
//     the raw source;
//   • string literals are kept intact: single-line, multi-line (`"""`), raw
//     (`#"…"#`, `##"""…"""##`), escapes and `\( … )` interpolation, which can
//     itself hold strings;
//   • `shape` is the same text, character for character, with every string
//     literal's CONTENT blanked to spaces, so brace depth can be measured.
//   • `executable` (corrective 3) is the shape view with every INACTIVE
//     conditional-compilation region — and every `#if`/`#elseif`/`#else`/
//     `#endif` line — blanked too, evaluated under `activeFlags` (the app's
//     DEBUG build, the configuration the harnesses prove). It is the code that
//     can actually execute: no comments, no string contents, no `#if false`.
// `Block` answers the structural questions on the EXECUTABLE view: where a
// call sits (its brace depth inside a function, the block that directly
// encloses it), how many `return`s precede it, and whether a straight path
// holds any exit at all. That's how "unconditional" and "reachable from this
// branch" are proven without compiling the scene. This is token awareness plus
// a local path check, deliberately not a Swift compiler.

import CryptoKit
import Foundation

enum SwiftSource {
    /// Comments removed; string literals intact.
    static func code(_ source: String) -> String { String(lex(Array(source), blankStrings: false)) }
    /// As `code`, with string-literal contents blanked (same character count).
    static func shape(_ source: String) -> String { String(lex(Array(source), blankStrings: true)) }
    /// As `shape`, with inactive conditional-compilation regions and the
    /// directive lines blanked (same character count): only executable code.
    static func executable(_ source: String) -> String { String(blankInactive(lex(Array(source), blankStrings: true)).chars) }

    /// The conditional-compilation flags the harnesses evaluate under: the
    /// app's DEBUG build. (The app's only directive today is `#if DEBUG`.)
    static let activeFlags: Set<String> = ["DEBUG"]

    /// Directive conditions this model can't evaluate. `block(in:after:)`
    /// refuses a source that has any, so a new form fails loudly instead of
    /// being guessed at.
    static func unsupportedDirectives(_ source: String) -> [String] {
        blankInactive(lex(Array(source), blankStrings: true)).unsupported
    }

    /// A directive line, parsed as TOKENS after lexical cleanup (comments are
    /// already blanks, string contents already blanked): optional whitespace
    /// (spaces or tabs), `#` immediately followed by the keyword, then the
    /// condition. Nil for any line that isn't one.
    private static func directive(_ line: ArraySlice<Character>) -> (keyword: String, rest: String)? {
        var k = line.startIndex
        while k < line.endIndex, line[k] == " " || line[k] == "\t" { k += 1 }
        guard k < line.endIndex, line[k] == "#" else { return nil }
        var e = k + 1
        while e < line.endIndex, line[e].isLetter { e += 1 }
        let keyword = String(line[(k + 1)..<e])
        guard ["if", "elseif", "else", "endif"].contains(keyword) else { return nil }
        guard e == line.endIndex || !(line[e].isNumber || line[e] == "_") else { return nil }
        return (keyword, String(line[e...]))
    }

    /// The condition forms the sources under test use, and the ruling names:
    /// `true`, `false`, a flag such as `DEBUG`, each optionally negated with
    /// `!`. Anything else is unsupported (nil).
    private static func evaluate(_ condition: String) -> Bool? {
        var text = Substring(condition.trimmingCharacters(in: .whitespaces))
        var negate = false
        while text.first == "!" { negate.toggle(); text = Substring(text.dropFirst().trimmingCharacters(in: .whitespaces)) }
        guard !text.isEmpty, text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        let value: Bool
        switch text {
        case "true": value = true
        case "false": value = false
        default: value = activeFlags.contains(String(text))
        }
        return negate ? !value : value
    }

    /// Blank every line of an inactive `#if` region, and every directive line,
    /// in a shape view (strings already blanked, so a `#if` inside a string
    /// literal is never a directive). Nesting, `#elseif` and `#else` handled.
    private static func blankInactive(_ shape: [Character]) -> (chars: [Character], unsupported: [String], blanked: [Bool]) {
        struct Frame { let parentActive: Bool; var taken: Bool; var active: Bool }
        var out = shape
        var blanked = [Bool](repeating: false, count: shape.count)
        var stack: [Frame] = []
        var unsupported: [String] = []
        var start = 0
        while start < shape.count {
            var end = start
            while end < shape.count, shape[end] != "\n" { end += 1 }
            let active = stack.last?.active ?? true
            var isDirective = false
            if let d = directive(shape[start..<end]) {
                isDirective = true
                let rest = d.rest.trimmingCharacters(in: .whitespaces)
                switch d.keyword {
                case "if":
                    let value = evaluate(rest)
                    if value == nil { unsupported.append("#if " + rest) }
                    stack.append(Frame(parentActive: active, taken: value ?? false, active: active && (value ?? false)))
                case "elseif":
                    let value = evaluate(rest)
                    if value == nil { unsupported.append("#elseif " + rest) }
                    if var top = stack.popLast() {
                        let v = !top.taken && (value ?? false)
                        top.active = top.parentActive && v
                        top.taken = top.taken || v
                        stack.append(top)
                    }
                case "else":
                    if !rest.isEmpty { unsupported.append("#else " + rest) }
                    if var top = stack.popLast() {
                        top.active = top.parentActive && !top.taken
                        top.taken = true
                        stack.append(top)
                    }
                default:                                            // endif
                    if !rest.isEmpty { unsupported.append("#endif " + rest) }
                    _ = stack.popLast()
                }
            }
            if isDirective || !active {
                for k in start..<end { out[k] = " "; blanked[k] = true }
            }
            start = end + 1
        }
        return (out, unsupported, blanked)
    }

    private enum Context { case code(parens: Int), string(multiline: Bool, hashes: Int) }

    private static func lex(_ c: [Character], blankStrings: Bool) -> [Character] { lexWithSpans(c, blankStrings: blankStrings).chars }

    /// The lexer. It also records the span of every OUTERMOST string literal
    /// (delimiters included; interpolations and any string nested inside them
    /// stay inside the span), so a literal can be one token (corrective 6).
    private static func lexWithSpans(_ c: [Character], blankStrings: Bool) -> (chars: [Character], spans: [Range<Int>]) {
        var out: [Character] = []
        var spans: [Range<Int>] = []
        var spanStart: Int?
        out.reserveCapacity(c.count)
        var stack: [Context] = [.code(parens: 0)]
        var i = 0
        func at(_ k: Int) -> Character? { k < c.count ? c[k] : nil }
        func matches(_ s: [Character], _ k: Int) -> Bool {
            guard k + s.count <= c.count else { return false }
            for j in 0..<s.count where c[k + j] != s[j] { return false }
            return true
        }
        while i < c.count {
            guard let context = stack.last else { break }
            switch context {
            case .code(let parens):
                if c[i] == "/", at(i + 1) == "/" {                  // line comment: blanks to the newline
                    while i < c.count, c[i] != "\n" { out.append(" "); i += 1 }
                    continue
                }
                if c[i] == "/", at(i + 1) == "*" {                  // block comment, nested: blanks, newlines kept
                    var depth = 0
                    while i < c.count {
                        if c[i] == "/", at(i + 1) == "*" { depth += 1; out.append(contentsOf: [" ", " "]); i += 2; continue }
                        if c[i] == "*", at(i + 1) == "/" {
                            depth -= 1; out.append(contentsOf: [" ", " "]); i += 2
                            if depth == 0 { break }
                            continue
                        }
                        out.append(c[i] == "\n" ? "\n" : " ")
                        i += 1
                    }
                    continue
                }
                var hashes = 0
                while at(i + hashes) == "#" { hashes += 1 }
                if at(i + hashes) == "\"" {                         // a string literal opens
                    let multiline = at(i + hashes + 1) == "\"" && at(i + hashes + 2) == "\""
                    let open = hashes + (multiline ? 3 : 1)
                    if spanStart == nil { spanStart = out.count }   // an outermost literal starts here
                    out.append(contentsOf: c[i..<(i + open)])
                    i += open
                    stack.append(.string(multiline: multiline, hashes: hashes))
                    continue
                }
                if c[i] == "(" { stack[stack.count - 1] = .code(parens: parens + 1) }
                if c[i] == ")" {
                    if parens == 0, stack.count > 1 {               // closes a `\( … )` interpolation
                        out.append(c[i]); i += 1
                        stack.removeLast()
                        continue
                    }
                    stack[stack.count - 1] = .code(parens: max(0, parens - 1))
                }
                out.append(c[i]); i += 1
            case .string(let multiline, let hashes):
                let close: [Character] = (multiline ? ["\"", "\"", "\""] : ["\""]) + Array(repeating: "#", count: hashes)
                if matches(close, i) {
                    out.append(contentsOf: close); i += close.count
                    stack.removeLast()
                    if !stack.contains(where: { if case .string = $0 { return true }; return false }), let start = spanStart {
                        spans.append(start..<out.count); spanStart = nil
                    }
                    continue
                }
                if c[i] == "\\", (0..<hashes).allSatisfy({ at(i + 1 + $0) == "#" }) {
                    let k = i + 1 + hashes
                    if at(k) == "(" {                               // interpolation: code until its `)`
                        out.append(contentsOf: c[i...k]); i = k + 1
                        stack.append(.code(parens: 0))
                        continue
                    }
                    let end = min(c.count, k + 1)                   // an escape: the backslash and its char
                    for ch in c[i..<end] { out.append(blankStrings && ch != "\n" ? " " : ch) }
                    i = end
                    continue
                }
                out.append(blankStrings && c[i] != "\n" ? " " : c[i]); i += 1
            }
        }
        return (out, spans)
    }

    /// A `{ … }` block (a function body, usually) located in sanitised source.
    struct Block {
        let code: [Character]      // comments removed, strings intact
        let shape: [Character]     // the same, string contents blanked
        let exec: [Character]      // the same, inactive `#if` regions and directives blanked too
        let active: [Character]    // the CODE view with inactive `#if` regions and directives blanked (strings intact)
        let spans: [Range<Int>]    // every outermost string literal, delimiters included
        let open: Int              // index of the block's `{`
        let close: Int             // index of its matching `}`

        var text: String { String(code[open...close]) }

        /// Offsets (into `code`) of every occurrence of `needle` inside the block.
        func offsets(of needle: String) -> [Int] {
            let n = Array(needle)
            guard !n.isEmpty, close - open >= n.count else { return [] }
            var found: [Int] = []
            var k = open
            while k + n.count <= close + 1 {
                var hit = true
                for j in 0..<n.count where code[k + j] != n[j] { hit = false; break }
                if hit { found.append(k); k += n.count } else { k += 1 }
            }
            return found
        }
        /// Occurrences of `needle` that are EXECUTABLE code: the match starts in
        /// code (not inside a string literal), and none of its code characters
        /// lies in an inactive conditional-compilation region.
        func executableOffsets(of needle: String) -> [Int] {
            offsets(of: needle).filter { o in
                guard shape[o] == code[o], exec[o] == code[o] else { return false }
                for j in 0..<needle.count where shape[o + j] == code[o + j] && exec[o + j] != code[o + j] { return false }
                return true
            }
        }
        /// Brace depth at `offset`, counted from the block itself (1 = directly inside it).
        func depth(at offset: Int) -> Int {
            var d = 0
            for k in open..<offset {
                if exec[k] == "{" { d += 1 } else if exec[k] == "}" { d -= 1 }
            }
            return d
        }
        /// True if the executable code in `from..<to` holds no exit statement at
        /// all (`return`, `throw`, `break`, `continue`, `fatalError`,
        /// `preconditionFailure`) and no `guard`: a straight path, so whatever
        /// is at `to` runs whenever `from` is reached.
        func exitFree(from: Int, to: Int) -> Bool {
            let words = ["return", "throw", "break", "continue", "fatalError", "preconditionFailure", "guard"].map(Array.init)
            func ident(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" }
            var k = max(from, open)
            while k < min(to, close) {
                for w in words where k + w.count <= exec.count && Array(exec[k..<(k + w.count)]) == w
                    && (k == 0 || !ident(exec[k - 1])) && (k + w.count >= exec.count || !ident(exec[k + w.count])) { return false }
                k += 1
            }
            return true
        }
        /// The `{` of the innermost block that encloses `offset`.
        func enclosingOpen(of offset: Int) -> Int? {
            var d = 0
            var k = offset - 1
            while k >= open {
                if exec[k] == "}" { d += 1 } else if exec[k] == "{" { if d == 0 { return k }; d -= 1 }
                k -= 1
            }
            return nil
        }
        /// The matching `}` of the `{` at `brace`.
        func matchingClose(of brace: Int) -> Int? {
            var d = 0
            for k in brace...close {
                if exec[k] == "{" { d += 1 } else if exec[k] == "}" { d -= 1; if d == 0 { return k } }
            }
            return nil
        }
        /// The block's DIRECT control-flow skeleton before `offset`, in order
        /// (corrective 4): every control keyword written directly in the block
        /// (`if`, `guard`, `else`, `for`, `while`, `repeat`, `switch`, `case`,
        /// `default`, `do`, `catch`, `defer`, `return`, `throw`, `break`,
        /// `continue`) and every block opened directly in it (`{`: an `if` or
        /// `guard` body, a loop, a closure…). Any added wrapper or guard changes
        /// it, whatever its terminating branch does.
        func skeleton(before offset: Int) -> [String] {
            let keywords: Set<String> = ["if", "guard", "else", "for", "while", "repeat", "switch", "case", "default",
                                         "do", "catch", "defer", "return", "throw", "break", "continue"]
            func ident(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" }
            var out: [String] = []
            var d = 0
            var k = open
            while k < min(offset, close) {
                let ch = exec[k]
                if ch == "{" { if d == 1 { out.append("{") }; d += 1; k += 1; continue }
                if ch == "}" { d -= 1; k += 1; continue }
                if ident(ch), k == 0 || !ident(exec[k - 1]) {
                    var e = k
                    while e < exec.count, ident(exec[e]) { e += 1 }
                    let word = String(exec[k..<e])
                    if d == 1, keywords.contains(word) { out.append(word) }
                    k = e
                    continue
                }
                k += 1
            }
            return out
        }
        /// The call at `offset` (`length` characters) is a STANDALONE statement
        /// in the frozen accepted shape (corrective 5), on the executable view:
        /// alone on its own line, and not joined into a larger expression by
        /// its neighbours — the previous executable line doesn't END, and the
        /// next doesn't BEGIN, with an operator or opener (`?`, `:`, `=`, a
        /// binary operator, `(`, `[`, `,`, `.`, a trailing-closure `{`…). A
        /// deliberate regression contract, not Swift equivalence: an
        /// equivalent but reformatted statement fails here on purpose.
        func isStandaloneStatement(at offset: Int, length: Int) -> Bool {
            func blank(_ ch: Character) -> Bool { ch == " " || ch == "\t" }
            var lineStart = offset
            while lineStart > 0, exec[lineStart - 1] != "\n" { lineStart -= 1 }
            var lineEnd = offset + length
            while lineEnd < exec.count, exec[lineEnd] != "\n" { lineEnd += 1 }
            let onOwnLine = exec[lineStart..<offset].allSatisfy(blank) && exec[(offset + length)..<lineEnd].allSatisfy(blank)
            let joiners: Set<Character> = ["?", ":", "=", "+", "-", "*", "/", "%", "&", "|", "^", "<", ">", "!", "~", "(", "[", ",", ".", "\\"]
            var p = lineStart - 1
            while p > open, blank(exec[p]) || exec[p] == "\n" { p -= 1 }
            let joinsPrevious = p > open && joiners.contains(exec[p])
            var n = lineEnd
            while n < close, blank(exec[n]) || exec[n] == "\n" { n += 1 }
            let joinsNext = n < close && !(exec[n].isLetter || exec[n] == "_" || exec[n] == "}")
            guard onOwnLine else { return false }
            guard !joinsPrevious else { return false }
            guard !joinsNext else { return false }
            return true
        }
        /// The EXACT active executable token sequence in `from..<to` (corrective
        /// 6), for pinning an accepted source shape. Whitespace and comments are
        /// ignored and inactive `#if` regions excluded; every other lexeme is
        /// kept verbatim: identifiers, keywords, numbers, operator runs,
        /// punctuation, and each string literal WHOLE (delimiters, contents,
        /// whitespace and interpolations exactly as written). Nothing semantic
        /// is normalized away, so an equivalent refactor changes it too.
        func tokens(from: Int, to: Int) -> [String] {
            let operatorChars: Set<Character> = ["/", "=", "-", "+", "!", "*", "%", "<", ">", "&", "|", "^", "~", "?", "."]
            func identStart(_ ch: Character) -> Bool { ch.isLetter || ch == "_" || ch == "$" || ch == "#" }
            func identChar(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" || ch == "$" }
            let literalEnd = Dictionary(uniqueKeysWithValues: spans.map { ($0.lowerBound, $0.upperBound) })
            var out: [String] = []
            var k = max(from, 0)
            let end = min(to, active.count)
            while k < end {
                let ch = active[k]
                if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" { k += 1; continue }
                if let e = literalEnd[k] { out.append(String(active[k..<e])); k = e; continue }
                var e = k + 1
                if identStart(ch) {
                    while e < end, identChar(active[e]) { e += 1 }
                } else if ch.isNumber {
                    while e < end, identChar(active[e]) || (active[e] == "." && e + 1 < end && active[e + 1].isNumber) { e += 1 }
                } else if operatorChars.contains(ch) {
                    while e < end, operatorChars.contains(active[e]) { e += 1 }
                }
                out.append(String(active[k..<e]))
                k = e
            }
            return out
        }
        /// `return` keywords in the block's executable code before `offset`.
        func returns(before offset: Int) -> Int {
            let word: [Character] = ["r", "e", "t", "u", "r", "n"]
            func ident(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" }
            var n = 0
            var k = open
            while k + word.count <= offset {
                if Array(exec[k..<(k + word.count)]) == word,
                   k == 0 || !ident(exec[k - 1]),
                   k + word.count >= exec.count || !ident(exec[k + word.count]) { n += 1; k += word.count } else { k += 1 }
            }
            return n
        }
    }

    /// SHA-256 (hex) of a token sequence, the tokens joined by U+001F: the
    /// fingerprint form for a pinned accepted token range (corrective 6).
    static func digest(_ tokens: [String]) -> String {
        SHA256.hash(data: Data(tokens.joined(separator: "\u{1F}").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The block that opens at the first `{` after the first EXECUTABLE
    /// occurrence of `signature` in `source` (a signature in a comment, a
    /// string or an inactive `#if` region never matches).
    static func block(in source: String, after signature: String) -> Block? {
        let (code, spans) = lexWithSpans(Array(source), blankStrings: false)
        let shape = lex(Array(source), blankStrings: true)
        let (exec, unsupported, blanked) = blankInactive(shape)
        let active = zip(code, blanked).map { $1 ? " " : $0 }
        let sig = Array(signature)
        guard unsupported.isEmpty else { return nil }             // a form this model can't evaluate: fail loudly
        guard !sig.isEmpty, code.count == shape.count, shape.count == exec.count else { return nil }
        var start: Int?
        var k = 0
        while k + sig.count <= code.count {
            var hit = exec[k] == code[k]
            if hit { for j in 0..<sig.count where code[k + j] != sig[j] { hit = false; break } }
            if hit { start = k; break }
            k += 1
        }
        guard let s = start, let open = exec[(s + sig.count)...].firstIndex(of: "{") else { return nil }
        var d = 0
        for k in open..<exec.count {
            if exec[k] == "{" { d += 1 } else if exec[k] == "}" { d -= 1; if d == 0 { return Block(code: code, shape: shape, exec: exec, active: active, spans: spans, open: open, close: k) } }
        }
        return nil
    }
}
