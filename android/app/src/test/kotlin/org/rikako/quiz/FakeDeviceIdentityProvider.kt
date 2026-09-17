package org.rikako.quiz

import org.rikako.quiz.data.identity.DeviceIdentityProvider

class FakeDeviceIdentityProvider(id: String) : DeviceIdentityProvider {
    private var current = id
    override suspend fun identityId(): String = current
    override suspend fun rotate(): String = current
    override suspend fun adopt(identityId: String) { current = identityId }
}
