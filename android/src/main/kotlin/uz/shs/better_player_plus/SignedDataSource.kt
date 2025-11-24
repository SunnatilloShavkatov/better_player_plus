package uz.shs.better_player_plus


import android.net.Uri
import android.util.Base64
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.HttpDataSource.HttpDataSourceException
import androidx.media3.datasource.TransferListener
import java.io.IOException
import java.nio.charset.StandardCharsets
import java.security.InvalidKeyException
import java.security.NoSuchAlgorithmException
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

@UnstableApi
class SignedHttpDataSource(
    private val upstreamDataSource: HttpDataSource, private val sig: String? = null
) : HttpDataSource {
    override fun addTransferListener(transferListener: TransferListener) {
        // It's important to delegate this call if the upstream source needs it
        upstreamDataSource.addTransferListener(transferListener)
    }

    @Throws(HttpDataSourceException::class)
    override fun open(dataSpec: DataSpec): Long {
        val signature = computeSignature(dataSpec)

        val dataSpecBuilder = dataSpec.buildUpon()

        // Option 2: Add as a query parameter (if queryParamName is set)
        val modifiedUri = dataSpec.uri.buildUpon().appendQueryParameter("sig", signature).build()
        dataSpecBuilder.setUri(modifiedUri)
        val modifiedDataSpec = dataSpecBuilder.build()
        return upstreamDataSource.open(modifiedDataSpec)
    }

    private fun computeSignature(dataSpec: DataSpec): String {
        return hmacSha256(dataSpec.uri.lastPathSegment ?: "", sig ?: "") ?: "NAN"
    }

    @Throws(IOException::class)
    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        return upstreamDataSource.read(buffer, offset, length)
    }

    override fun getUri(): Uri? {
        return upstreamDataSource.uri
    }

    override fun getResponseHeaders(): Map<String, List<String>> {
        return upstreamDataSource.responseHeaders
    }

    @Throws(IOException::class)
    override fun close() {
        upstreamDataSource.close()
    }

    // HttpDataSource specific methods
    override fun setRequestProperty(name: String, value: String) {
        // This method is generally used to set default headers on the *factory*
        // or *before* open() is called on a specific instance.
        // Our signing logic is per-request in open(), so we modify DataSpec there.
        // However, the underlying source might still use this.
        upstreamDataSource.setRequestProperty(name, value)
    }

    override fun clearRequestProperty(name: String) {
        upstreamDataSource.clearRequestProperty(name)
    }

    override fun clearAllRequestProperties() {
        upstreamDataSource.clearAllRequestProperties()
    }

    override fun getResponseCode(): Int {
        return upstreamDataSource.responseCode
    }

    companion object {


        private const val TAG = "CryptoUtils"
        private const val HMAC_SHA256_ALGORITHM = "HmacSHA256"

        /**
         * Computes the HMAC-SHA256 hash of the given data using the provided secret key.
         *
         * @param data The string data to hash.
         * @param secretKey The secret key for the HMAC operation.
         * @return The Base64 encoded HMAC-SHA256 hash string, or null if an error occurs.
         */
        fun hmacSha256(data: String, secretKey: String): String? {
            return try {
                // 1. Get an instance of the HmacSHA256 Mac
                val mac = Mac.getInstance(HMAC_SHA256_ALGORITHM)

                // 2. Create a SecretKeySpec from the secret key bytes
                //    Ensure your key is in UTF-8 bytes or the appropriate encoding
                val secretKeyBytes = secretKey.toByteArray(StandardCharsets.UTF_8)
                val secretKeySpec = SecretKeySpec(
                    secretKeyBytes, HMAC_SHA256_ALGORITHM
                )

                // 3. Initialize the Mac with the secret key
                mac.init(secretKeySpec)

                // 4. Compute the HMAC on the data bytes
                //    Ensure your data is in UTF-8 bytes or the appropriate encoding
                val dataBytes = data.toByteArray(StandardCharsets.UTF_8)
                val hmacBytes = mac.doFinal(dataBytes)

                // 5. Encode the resulting byte array to a Base64 string
                //    Base64.NO_WRAP is important to avoid newlines in the output string
                Base64.encodeToString(hmacBytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP).trim()

            } catch (e: NoSuchAlgorithmException) {
                Log.e(
                    TAG, "HMAC-SHA256 algorithm not found. This should not happen on Android.", e
                )
                null
            } catch (e: InvalidKeyException) {
                Log.e(TAG, "Invalid secret key for HMAC-SHA256.", e)
                null
            } catch (e: Exception) { // Catch any other unexpected exceptions
                Log.e(TAG, "Error computing HMAC-SHA256", e)
                null
            }
        }

    }
}