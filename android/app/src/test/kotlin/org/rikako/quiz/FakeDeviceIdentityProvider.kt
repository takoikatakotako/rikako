package org.rikako.quiz

import org.rikako.quiz.data.identity.DeviceIdentityProvider

class FakeDeviceIdentityProvider(private val id: String) : DeviceIdentityProvider {
    override suspend fun identityId(): String = id
    override suspend fun rotate(): String = id
}
