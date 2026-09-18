package org.rikako.quiz

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.rikako.quiz.ui.mypage.transferQrBitmap

@RunWith(AndroidJUnit4::class)
class TransferQrCodeTest {
    @Test fun 表示するQRコードは元のトークンに戻せる() {
        val token = "a".repeat(64)
        val bitmap = transferQrBitmap(token)
        try {
            val pixels = IntArray(bitmap.width * bitmap.height)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            val image = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(bitmap.width, bitmap.height, pixels)))
            assertEquals(token, QRCodeReader().decode(image).text)
        } finally {
            bitmap.recycle()
        }
    }
}
