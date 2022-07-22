# Appcircle SonarQube Component

This step installs [SonarQube CLI](https://www.sonarqube.org/) and runs `sonar-scanner` with given options.

**Optional Input Variables**
- `$AC_SONAR_VERSION`: SonarQube CLI version. If no version is given latest will be used.
- `$AC_SONAR_PARAMETERS`: Scanner parameters written in Java properties format. If your project has `sonar-project.properties` file it will append those properties to your file. Leave empty if you want to use your own file.
- `$AC_SONAR_EXTRA_PARAMETERS`: Extra command line parameters for `sonar-scanner` command. Enter **-X** for debug mode.
