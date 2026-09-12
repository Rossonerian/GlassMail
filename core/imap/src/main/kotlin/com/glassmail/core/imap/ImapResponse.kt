package com.glassmail.core.imap

sealed interface ImapValue {
    data class Atom(val value: String) : ImapValue
    data class Quoted(val value: String) : ImapValue
    data class Literal(val bytes: ByteArray) : ImapValue
    data class List(val values: kotlin.collections.List<ImapValue>) : ImapValue
    data object Nil : ImapValue
}

sealed interface ImapResponse {
    data class Untagged(val values: List<ImapValue>) : ImapResponse
    data class Tagged(val tag: String, val status: String, val values: List<ImapValue>) : ImapResponse
    data class Continuation(val text: String) : ImapResponse
}

fun ImapValue.atomValue(): String? = when (this) {
    is ImapValue.Atom -> value
    is ImapValue.Quoted -> value
    ImapValue.Nil, is ImapValue.Literal, is ImapValue.List -> null
}

fun ImapValue.literalValue(): ByteArray? = (this as? ImapValue.Literal)?.bytes

fun ImapValue.listValue(): List<ImapValue> = (this as? ImapValue.List)?.values.orEmpty()

fun List<ImapValue>.attribute(name: String): ImapValue? {
    val index = indexOfFirst { it.atomValue()?.equals(name, ignoreCase = true) == true }
    return getOrNull(index + 1)
}

object ImapResponseParser {
    fun parse(line: String, literals: List<ByteArray>): ImapResponse {
        require(line.isNotBlank()) { "Empty IMAP response" }
        return when {
            line.startsWith("+") -> ImapResponse.Continuation(line.drop(1).trimStart())
            line.startsWith("* ") -> ImapResponse.Untagged(ValueParser(line.drop(2), literals).parseAll())
            else -> {
                val parser = ValueParser(line, literals)
                val values = parser.parseAll()
                require(values.size >= 2) { "Malformed tagged IMAP response" }
                ImapResponse.Tagged(
                    tag = values[0].atomValue() ?: error("Invalid IMAP tag"),
                    status = values[1].atomValue() ?: error("Invalid IMAP status"),
                    values = values.drop(2),
                )
            }
        }
    }

    private class ValueParser(
        private val input: String,
        private val literals: List<ByteArray>,
    ) {
        private var position = 0

        fun parseAll(): List<ImapValue> = buildList {
            skipWhitespace()
            while (position < input.length) {
                add(parseValue())
                skipWhitespace()
            }
        }

        private fun parseValue(): ImapValue = when (input[position]) {
            '(' -> parseList()
            '"' -> ImapValue.Quoted(parseQuoted())
            '\u0000' -> parseLiteralReference()
            else -> parseAtom()
        }

        private fun parseList(): ImapValue.List {
            position++
            val values = buildList {
                skipWhitespace()
                while (position < input.length && input[position] != ')') {
                    add(parseValue())
                    skipWhitespace()
                }
            }
            require(position < input.length && input[position] == ')') { "Unterminated IMAP list" }
            position++
            return ImapValue.List(values)
        }

        private fun parseQuoted(): String {
            position++
            val value = StringBuilder()
            while (position < input.length) {
                when (val character = input[position++]) {
                    '"' -> return value.toString()
                    '\\' -> {
                        require(position < input.length) { "Invalid quoted IMAP string" }
                        value.append(input[position++])
                    }
                    else -> value.append(character)
                }
            }
            error("Unterminated quoted IMAP string")
        }

        private fun parseLiteralReference(): ImapValue.Literal {
            val start = position
            val end = input.indexOf('\u0000', startIndex = start + 1)
            require(end > start) { "Invalid IMAP literal marker" }
            val marker = input.substring(start + 1, end)
            require(marker.startsWith("L")) { "Invalid IMAP literal marker" }
            position = end + 1
            return ImapValue.Literal(literals[marker.drop(1).toInt()])
        }

        private fun parseAtom(): ImapValue {
            val start = position
            while (position < input.length && !input[position].isWhitespace() && input[position] !in "()") {
                position++
            }
            require(start != position) { "Invalid IMAP atom" }
            val value = input.substring(start, position)
            return if (value.equals("NIL", ignoreCase = true)) ImapValue.Nil else ImapValue.Atom(value)
        }

        private fun skipWhitespace() {
            while (position < input.length && input[position].isWhitespace()) position++
        }
    }
}
