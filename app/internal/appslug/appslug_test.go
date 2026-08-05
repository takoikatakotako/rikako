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
