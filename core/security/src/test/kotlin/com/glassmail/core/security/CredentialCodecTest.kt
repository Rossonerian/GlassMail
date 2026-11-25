package com.glassmail.core.security

import java.nio.charset.StandardCharsets
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CredentialCodecTest {

    @Test
    fun asciiRoundtripHasExactLengthAndNoTrailingNul() {
        val original = "app-password-1234!@#"
        val chars = original.toCharArray()

        val encoded = encodeCredential(chars)
        assertEquals(original.length, encoded.size)
        assertArrayEquals(original.toByteArray(StandardCharsets.UTF_8), encoded)
        assertTrue(encoded.none { it == 0.toByte() })

        val decoded = decodeCredential(encoded)
        assertEquals(chars.size, decoded.size)
        assertArrayEquals(chars, decoded)
        assertTrue(decoded.none { it == '\u0000' })
    }

    @Test
    fun multiByteUtf8RoundtripHasExactLengthAndNoTrailingNul() {
        val original = "päss-🔑-日本語-€"
        val chars = original.toCharArray()
        val expectedBytes = original.toByteArray(StandardCharsets.UTF_8)

        val encoded = encodeCredential(chars)
        assertEquals(expectedBytes.size, encoded.size)
        assertArrayEquals(expectedBytes, encoded)
        assertTrue(encoded.none { it == 0.toByte() })

        val decoded = decodeCredential(encoded)
        assertEquals(chars.size, decoded.size)
        assertArrayEquals(chars, decoded)
        assertTrue(decoded.none { it == '\u0000' })
    }

    @Test
    fun emptyCredentialRoundtripReturnsEmptyArrays() {
        val encoded = encodeCredential(CharArray(0))
        assertEquals(0, encoded.size)

        val decoded = decodeCredential(ByteArray(0))
        assertEquals(0, decoded.size)
    }

    @Test
    fun zeroingIntermediateArraysDoesNotCorruptIndependentCopy() {
        val input = "secret-🔑-utf8".toCharArray()
        val expected = input.copyOf()

        val encoded = encodeCredential(input)
        input.fill('\u0000')
        assertTrue(input.all { it == '\u0000' })

        val decoded = decodeCredential(encoded)
        encoded.fill(0)
        assertTrue(encoded.all { it == 0.toByte() })

        assertArrayEquals(expected, decoded)

        decoded.fill('\u0000')
        assertTrue(decoded.all { it == '\u0000' })
    }
}
