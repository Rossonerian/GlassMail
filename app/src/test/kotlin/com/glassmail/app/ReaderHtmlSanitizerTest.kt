package com.glassmail.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReaderHtmlSanitizerTest {

    @Test
    fun `stripTrackingPixels removes meta, svg, stray svg, and unsafe data URIs without incrementing tracker count`() {
        val html = """
            <meta http-equiv="refresh" content="0;url=https://evil.example">
            <svg onload="alert(1)"><circle r="10"/></svg>
            <svg width="10" height="10" />
            <svg><rect>
            </svg>
            <img src="data:image/svg+xml;base64,PHN2Zz4=">
            <img src="data:image/png+xml,evil">
            <img src="data:image/png;base64,AAAA" width="40" height="40">
            <p>Hello</p>
        """.trimIndent()

        val (cleaned, trackerCount) = stripTrackingPixels(html)

        assertEquals(0, trackerCount)
        assertFalse(cleaned.contains("<meta", ignoreCase = true))
        assertFalse(cleaned.contains("<svg", ignoreCase = true))
        assertFalse(cleaned.contains("</svg>", ignoreCase = true))
        assertFalse(cleaned.contains("data:image/svg+xml", ignoreCase = true))
        assertFalse(cleaned.contains("data:image/png+xml", ignoreCase = true))
        assertTrue(cleaned.contains("data:image/png;base64,AAAA"))
        assertTrue(cleaned.contains("<p>Hello</p>"))
    }

    @Test
    fun `shouldOpenMailNavigation requires main frame, user gesture, and non-redirect`() {
        assertTrue(shouldOpenMailNavigation(isForMainFrame = true, hasGesture = true, isRedirect = false))
        assertFalse(shouldOpenMailNavigation(isForMainFrame = false, hasGesture = true, isRedirect = false))
        assertFalse(shouldOpenMailNavigation(isForMainFrame = true, hasGesture = false, isRedirect = false))
        assertFalse(shouldOpenMailNavigation(isForMainFrame = true, hasGesture = true, isRedirect = true))
    }

    @Test
    fun `isSafeInlineDataUri allows safe raster image types and blocks active or crafted types`() {
        assertTrue(isSafeInlineDataUri("data:image/png;base64,AAAA"))
        assertTrue(isSafeInlineDataUri("data:image/jpeg;base64,AAAA"))
        assertTrue(isSafeInlineDataUri("data:image/webp,AAAA"))
        assertFalse(isSafeInlineDataUri("data:image/svg+xml,<svg/>"))
        assertFalse(isSafeInlineDataUri("data:image/png+xml,evil"))
        assertFalse(isSafeInlineDataUri("data:text/html,<script>alert(1)</script>"))
    }
}
