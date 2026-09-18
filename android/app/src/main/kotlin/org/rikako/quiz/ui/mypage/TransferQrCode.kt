package org.rikako.quiz.ui.mypage

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeWriter
import kotlin.math.max

internal fun normalizedTransferToken(value: String): String? =
    value.trim().takeIf { it.matches(Regex("[0-9a-fA-F]{64}")) }?.lowercase()

internal fun transferQrBitmap(token: String): Bitmap {
    val matrix = QRCodeWriter().encode(
        token,
        BarcodeFormat.QR_CODE,
        640,
        640,
        mapOf(EncodeHintType.MARGIN to 3),
    )
    val pixels = IntArray(matrix.width * matrix.height) { index ->
        if (matrix[index % matrix.width, index / matrix.width]) android.graphics.Color.BLACK
        else android.graphics.Color.WHITE
    }
    return Bitmap.createBitmap(pixels, matrix.width, matrix.height, Bitmap.Config.ARGB_8888)
}

/** 写真選択には端末のシステム UI を使い、画像は最大 2048px に縮小して読む。 */
internal fun readTransferQrFromImage(resolver: ContentResolver, uri: Uri): String? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    val sample = generateSequence(1) { it * 2 }
        .first { max(bounds.outWidth, bounds.outHeight) / it <= 2048 }
    val bitmap = resolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
    } ?: return null
    return try {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val image = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(bitmap.width, bitmap.height, pixels)))
        val result = MultiFormatReader().decode(
            image,
            mapOf(DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE), DecodeHintType.TRY_HARDER to true),
        )
        normalizedTransferToken(result.text)
    } catch (_: Exception) {
        null
    } finally {
        bitmap.recycle()
    }
}
