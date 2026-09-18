package appslug

import "testing"

func TestVersionOverride(t *testing.T) {
	const def = "1.0.0"

	t.Run("slug 空はデフォルト", func(t *testing.T) {
		if got := VersionOverride(def, "MINIMUM_VERSION", ""); got != def {
			t.Errorf("want %s, got %s", def, got)
		}
	})

	t.Run("env 未設定はデフォルト", func(t *testing.T) {
		if got := VersionOverride(def, "MINIMUM_VERSION", "it-passport"); got != def {
			t.Errorf("want %s, got %s", def, got)
		}
	})

	t.Run("slug 別 env で上書き（ハイフンは大文字_に正規化）", func(t *testing.T) {
		t.Setenv("MINIMUM_VERSION_IT_PASSPORT", "1.2.3")
		if got := VersionOverride(def, "MINIMUM_VERSION", "it-passport"); got != "1.2.3" {
			t.Errorf("want 1.2.3, got %s", got)
		}
		// 別 slug は影響を受けずデフォルト。
		if got := VersionOverride(def, "MINIMUM_VERSION", "high-school-chemistry"); got != def {
			t.Errorf("want %s, got %s", def, got)
		}
	})
}

func TestPlatformVersionOverride(t *testing.T) {
	const shared = "3.1.0"
	t.Setenv("MINIMUM_VERSION_HIGH_SCHOOL_CHEMISTRY", "3.0.0")
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "high-school-chemistry", ""); got != "3.0.0" {
		t.Errorf("旧 iOS クライアント: want 3.0.0, got %s", got)
	}
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "high-school-chemistry", "ios"); got != "3.0.0" {
		t.Errorf("iOS: want 3.0.0, got %s", got)
	}
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "high-school-chemistry", "android"); got != "1.0.0" {
		t.Errorf("Android は iOS の最小バージョンを継承しない: want 1.0.0, got %s", got)
	}

	t.Setenv("MINIMUM_VERSION_ANDROID", "1.1.0")
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "high-school-chemistry", "android"); got != "1.1.0" {
		t.Errorf("Android 共通設定: want 1.1.0, got %s", got)
	}
	t.Setenv("MINIMUM_VERSION_ANDROID_HIGH_SCHOOL_CHEMISTRY", "1.2.0")
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "high-school-chemistry", "android"); got != "1.2.0" {
		t.Errorf("Android アプリ別設定: want 1.2.0, got %s", got)
	}
	if got := PlatformVersionOverride(shared, "MINIMUM_VERSION", "it-passport", "android"); got != "1.1.0" {
		t.Errorf("別アプリは Android 共通設定: want 1.1.0, got %s", got)
	}
}
