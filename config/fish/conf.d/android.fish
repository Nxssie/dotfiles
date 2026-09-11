# Android SDK (~/Android/Sdk, installed by Android Studio). Guarded so machines
# without the SDK get a no-op. fish_add_path is idempotent and prepends, so adb
# always wins over any stray copy.
set -l sdk "$HOME/Android/Sdk"
if test -d "$sdk"
    set -gx ANDROID_HOME "$sdk"
    set -gx ANDROID_SDK_ROOT "$sdk"
    fish_add_path --global --move \
        "$sdk/platform-tools" \
        "$sdk/cmdline-tools/latest/bin" \
        "$sdk/emulator"
end
