# WorkManager (per play-services-ads-api transitiv eingebunden) nutzt Room
# für seine interne Datenbank — Room generiert die eigentlichen DAO-/
# Datenbank-Implementierungsklassen erst beim Kompilieren (Annotation
# Processing). Ohne diese Keep-Regeln entfernt/verstümmelt R8 sie im
# Release-Build, was beim App-Start zu "Failed to create an instance of
# androidx.work.impl.WorkDatabase" führt.
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-keep interface androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-dontwarn androidx.room.paging.**
