package org.rikako.quiz

import android.app.Application

class RikakoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ServiceLocator.init(this)
    }
}
