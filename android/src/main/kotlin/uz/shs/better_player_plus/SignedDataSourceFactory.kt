package uz.shs.better_player_plus

import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener

@UnstableApi
class SignedHttpDataSourceFactory(
    userAgent: String?,// Optional
    private val sig: String?
) : HttpDataSource.Factory {
    private val defaultHttpDataSourceFactory =
        DefaultHttpDataSource.Factory().setUserAgent(userAgent)
            .setAllowCrossProtocolRedirects(true) // A common sensible default
    private var transferListener: TransferListener? = null

    override fun createDataSource(): SignedHttpDataSource {
        // Create the actual HttpDataSource that will do the network request
        val upstream = defaultHttpDataSourceFactory.createDataSource()
        if (transferListener != null) {
            upstream.addTransferListener(transferListener!!)
        }
        return SignedHttpDataSource(upstream, sig)
    }

    override fun setDefaultRequestProperties(
        defaultRequestProperties: Map<String, String>
    ): HttpDataSource.Factory {
        defaultHttpDataSourceFactory.setDefaultRequestProperties(
            defaultRequestProperties
        )
        return this
    }

    fun setConnectTimeoutMs(connectTimeoutMs: Int): SignedHttpDataSourceFactory {
        defaultHttpDataSourceFactory.setConnectTimeoutMs(connectTimeoutMs)
        return this
    }

    fun setReadTimeoutMs(readTimeoutMs: Int): SignedHttpDataSourceFactory {
        defaultHttpDataSourceFactory.setReadTimeoutMs(readTimeoutMs)
        return this
    }

    fun setAllowCrossProtocolRedirects(
        allow: Boolean
    ): SignedHttpDataSourceFactory {
        defaultHttpDataSourceFactory.setAllowCrossProtocolRedirects(allow)
        return this
    }

    fun setTransferListener(
        transferListener: TransferListener?
    ): SignedHttpDataSourceFactory {
        this.transferListener = transferListener
        // Also set it on the underlying factory if it's already created,
        // though createDataSource() will handle it for new instances.
        defaultHttpDataSourceFactory.setTransferListener(transferListener)
        return this
    }
}