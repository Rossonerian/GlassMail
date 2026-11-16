package com.glassmail.core.imap

import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.Locale

/** RFC 5322 dates, including obsolete syntax commonly returned in IMAP ENVELOPE. */
internal object ImapDates {
    private val date = Regex(
        "^(?:[A-Za-z]{3}\\s*,?\\s+)?(\\d{1,2})\\s+([A-Za-z]{3})\\s+(\\d{2,})\\s+" +
            "(\\d{1,2})\\s*:\\s*(\\d{2})(?:\\s*:\\s*(\\d{2}))?\\s+([+-]\\d{4}|[A-Za-z]+)$",
    )
    private val months = listOf("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
    private val obsoleteZones = mapOf(
        "UT" to 0, "GMT" to 0, "UTC" to 0,
        "EST" to -5, "EDT" to -4, "CST" to -6, "CDT" to -5,
        "MST" to -7, "MDT" to -6, "PST" to -8, "PDT" to -7,
    )

    fun header(value: String?): Long? = value?.let { raw ->
        runCatching {
            val normalized = stripComments(raw)?.replace(Regex("\\s+"), " ")?.trim() ?: return null
            val parts = date.matchEntire(normalized)?.groupValues ?: return null
            val year = parts[3].toInt().let {
                when {
                    parts[3].length == 2 -> if (it < 50) it + 2000 else it + 1900
                    parts[3].length == 3 -> it + 1900
                    else -> it
                }
            }
            val zone = parts[7].uppercase(Locale.ROOT)
            val offset = if (zone.startsWith('+') || zone.startsWith('-')) {
                ZoneOffset.of(zone)
            } else {
                val hours = obsoleteZones[zone]
                    // RFC 5322 obs-zone military letters represent an unknown local offset.
                    ?: if (zone.length == 1 && zone[0] in 'A'..'Z' && zone != "J") 0 else return null
                ZoneOffset.ofHours(hours)
            }
            val seconds = parts[6].ifEmpty { "0" }.toInt()
            LocalDateTime.of(year, months.indexOf(parts[2].lowercase(Locale.ROOT)) + 1,
                parts[1].toInt(), parts[4].toInt(), parts[5].toInt(), seconds.coerceAtMost(59))
                .toInstant(offset).toEpochMilli().let { if (seconds == 60) it + 1000 else if (seconds > 60) null else it }
        }.getOrNull()
    }

    fun internalDate(value: String?): Long? = value?.trim()?.let { raw ->
        // IMAP permits a space-padded one-digit day as well as dd-MMM-yyyy.
        header(raw.replaceFirst(Regex("^(\\d{1,2})-([A-Za-z]{3})-(\\d{4})"), "$1 $2 $3"))
    }

    private fun stripComments(value: String): String? {
        val result = StringBuilder()
        var depth = 0
        var escaped = false
        for (character in value) {
            when {
                depth > 0 && escaped -> escaped = false
                depth > 0 && character == '\\' -> escaped = true
                character == '(' -> { depth++; result.append(' ') }
                character == ')' -> { if (depth == 0) return null; depth-- }
                depth == 0 -> result.append(character)
            }
        }
        return if (depth == 0) result.toString() else null
    }
}
