package org.rikako.quiz

import android.app.Application
import kotlinx.coroutines.launch

class RikakoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ServiceLocator.init(this)
        // リンクに失敗したまま終了していた場合に備えて、起動時にもやり直す。
        // 失敗は AccountRepository.linkState に出るので、アカウント画面から再試行できる。
        ServiceLocator.applicationScope.launch {
            runCatching { ServiceLocator.accountRepository.ensureLinked() }
        }
    }
}
