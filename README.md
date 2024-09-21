xyloid
===

[![Maven Central](https://img.shields.io/maven-central/v/com.io7m.xyloid/com.io7m.xyloid.natives.svg?style=flat-square)](http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22com.io7m.xyloid%22)

![com.io7m.xyloid](./src/site/resources/xyloid.jpg?raw=true)

## xyloid

Repackaged [xerial sqlite-jdbc](https://github.com/xerial/sqlite-jdbc) binaries for Android.

### Features

* SQLite binaries packaged as a convenient `.aar` package.

### Motivation

When developing Android applications, the sensible approach is to have as little of the application
depend on the Android APIs directly. This is a sensible approach for two main reasons:

* The Android APIs are extremely poorly engineered, and each poorly engineered API tends to be
  replaced with a new poorly engineered API on a repeating schedule. This means that applications
  depending on those APIs get to be repeatedly rewritten.
* As soon as any part of an application depends on an Android API, it's no longer possible to
  write automated tests for that part of the application without either using extremely
  fragile and frequently-broken _instrumented device tests_, or going through hacky solutions
  such as [RoboElectric](https://robolectric.org/).

In accordance with this approach, it follows that any application that uses a relational database
for local state should do so through the standardized
[JDBC](https://en.wikipedia.org/wiki/Java_Database_Connectivity) APIs rather than depending on
anything Android provides.

Unfortunately, even though Android bundles a version of the [SQLite](https://www.sqlite.org)
database, the Android team refuse to publish a driver for the version of SQLite bundled with 
Android. This means that any part of the application that uses the database immediately becomes 
dependent on a proprietary Android API, causing the issues detailed above.

Thankfully, the excellent [xerial sqlite-jdbc](https://github.com/xerial/sqlite-jdbc) project
publishes a version of SQLite compiled for Android, complete with a full JDBC driver. Unfortunately,
due to Android using an entirely custom packaging system for no reason whatsoever, there are some
extra steps required to use the `xerial` binaries in an Android application.

The `xyloid` package simply repackages the `xerial` binaries such that they can be specified
as a dependency in Android applications, and used without any extra steps required.

### Usage

The core of your application should be written without any dependencies on the Android API.
This platform-independent code should specify a dependency on the normal upstream xerial
`sqlite-jdbc` artifacts. Those artifacts provide the Java bytecode for the JDBC driver:

```
$ cat core/build.gradle.kts
dependencies {
  implementation("org.xerial:sqlite-jdbc:${LATEST_VERSION}")
}
...
```

Then, the Android-dependent submodule that produces the actual `apk` or `aab` file for the
application should specify a dependency on the core, and on the `xyloid` `aar` package:

```
$ cat app/build.gradle.kts
dependencies {
  implementation(project(":core"))
  implementation("com.io7m.xyloid:com.io7m.xyloid.natives:${LATEST_VERSION}")
}

android {
  buildTypes {
    debug {
      ndk {
        abiFilters.add("x86")
        abiFilters.add("x86_64")
        abiFilters.add("arm64-v8a")
        abiFilters.add("armeabi")
      }
      versionNameSuffix = "-debug"
    }
    release {
      ndk {
        abiFilters.add("x86")
        abiFilters.add("x86_64")
        abiFilters.add("arm64-v8a")
        abiFilters.add("armeabi")
      }
    }
  }
}
```

With this setup, you can write unit tests for the core of the application as plain JUnit tests
and run them on your local machine. When run like this, the `sqlite` binaries from the
`org.xerial:sqlite-jdbc` package will be used. Additionally, when your Android application
`app` module is assembled, the binaries from the `com.io7m.xyloid:com.io7m.xyloid.natives` will
be used instead, and this will result in the correct binaries being present in the `apk/aab`.
