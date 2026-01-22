# Amazon IVS Player - Ignore missing Cronet classes
# These are optional dependencies that IVS references but doesn't require
-dontwarn org.chromium.net.CronetEngine$Builder
-dontwarn org.chromium.net.CronetEngine
-dontwarn org.chromium.net.CronetException
-dontwarn org.chromium.net.UploadDataProvider
-dontwarn org.chromium.net.UploadDataProviders
-dontwarn org.chromium.net.UrlRequest$Builder
-dontwarn org.chromium.net.UrlRequest$Callback
-dontwarn org.chromium.net.UrlRequest
-dontwarn org.chromium.net.UrlResponseInfo

# Keep all Cronet classes if they exist (prevents stripping if added later)
-keep class org.chromium.net.** { *; }

# Keep Amazon IVS classes
-keep class com.amazonaws.ivs.** { *; }
