package com.glassmail.data.mail

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FtsExpressionTest {
    @Test fun `each word becomes an AND-joined prefix phrase so partial typing matches`() {
        assertEquals("\"secur*\" AND \"alert*\"", "Secur alert".toFtsMatchExpression())
    }

    @Test fun `punctuation and underscores split into separate tokens`() {
        assertEquals("\"gm*\" AND \"t1*\" AND \"self*\" AND \"test*\"", "GM-T1_self_test".toFtsMatchExpression())
    }

    @Test fun `quotes and operators cannot inject FTS syntax`() {
        assertEquals("\"a*\" AND \"or*\" AND \"b*\"", "\"a\" OR -b*".toFtsMatchExpression())
    }

    @Test fun `empty or punctuation only input yields no query`() {
        assertNull("".toFtsMatchExpression())
        assertNull(" -- ** ".toFtsMatchExpression())
    }
}
