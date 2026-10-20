# Appcircle SonarQube Component

This step installs [SonarQube CLI](https://www.sonarqube.org/) and runs `sonar-scanner` with given options.

**Optional Input Variables**
- `$AC_SONAR_VERSION`: SonarQube CLI version. Defaults to `8.2.0.6438`. Enter `latest` to use the newest version published at the download location (read from its `maven-metadata.xml`).
- `$AC_SONAR_SCANNER_BASE_URL`: Base URL to download the scanner from, in the Maven repository layout of `org.sonarsource.scanner.cli:sonar-scanner-cli`. Defaults to Maven Central (`https://repo1.maven.org/maven2/org/sonarsource/scanner/cli/sonar-scanner-cli`). In air-gapped environments, point it to your artifact proxy, for example `https://nexus.example.com/repository/maven-public/org/sonarsource/scanner/cli/sonar-scanner-cli`.
- `$AC_SONAR_PARAMETERS`: Scanner parameters written in Java properties format. If your project has `sonar-project.properties` file it will append those properties to your file. Leave empty if you want to use your own file.
- `$AC_SONAR_EXTRA_PARAMETERS`: Extra command line parameters for `sonar-scanner` command. Enter **-X** for debug mode.

The step downloads the scanner zip and its `.sha256` file from the base URL and stops if the checksum does not match. If `sonar-scanner` of the requested version is already on `PATH`, the download is skipped. Set `sonar.host.url` to your SonarQube server. The scanner downloads the Java runtime for the analysis from that server (JRE auto-provisioning), so it needs no other host. Without `sonar.host.url`, the scanner uses SonarCloud and its first request goes to `https://api.sonarcloud.io/analysis/jres`, which fails in networks without internet access. If you turn JRE provisioning off (`-Dsonar.scanner.skipJreProvisioning=true`), the Java on `PATH` must meet the server's requirement: SonarQube 26.10 rejects Java 17 and needs Java 21.
