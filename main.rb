require "pathname"
require "digest"
require "open3"
require "shellwords"

DEFAULT_SCANNER_VERSION = "8.2.0.6438"
DEFAULT_SCANNER_BASE_URL = "https://repo1.maven.org/maven2/org/sonarsource/scanner/cli/sonar-scanner-cli"

def env_has_key(key)
  !ENV[key].nil? && ENV[key] != "" ? ENV[key] : abort("Missing #{key}.")
end

def run_command(command)
  puts "@@[command] #{command}"
  unless system(command)
    exit $?.exitstatus
  end
end

def fetch(url)
  output, status = Open3.capture2("curl", "-fsSL", "--retry", "3", url)
  abort("Could not download #{url}") unless status.success?
  output
end

# The base URL follows the Maven repository layout of org.sonarsource.scanner.cli:sonar-scanner-cli,
# so an artifact proxy that already proxies Maven Central serves it without a new repository.
def scanner_base_url
  base_url = ENV["AC_SONAR_SCANNER_BASE_URL"].to_s.strip
  base_url = DEFAULT_SCANNER_BASE_URL if base_url.empty?
  abort("AC_SONAR_SCANNER_BASE_URL must start with http:// or https://") unless base_url.match?(%r{\Ahttps?://})
  base_url.chomp("/")
end

def resolve_version(base_url)
  version = ENV["AC_SONAR_VERSION"].to_s.strip
  version = DEFAULT_SCANNER_VERSION if version.empty?
  if version == "latest"
    puts "Getting the latest SonarScanner CLI version from #{base_url}/maven-metadata.xml"
    version = fetch("#{base_url}/maven-metadata.xml")[%r{<release>([^<]+)</release>}, 1].to_s
    abort("Could not read the latest version from #{base_url}/maven-metadata.xml") if version.empty?
  end
  abort("Invalid SonarScanner CLI version: #{version}") unless version.match?(/\A[0-9A-Za-z.\-]+\z/)
  version
end

# A scanner of the requested version already on PATH (for example baked into the VM image) is used as is.
def installed_scanner(version)
  ENV["PATH"].to_s.split(File::PATH_SEPARATOR).each do |dir|
    path = File.join(dir, "sonar-scanner")
    next unless File.file?(path) && File.executable?(path)

    output, = Open3.capture2e(path, "--version")
    return path if output.include?(version)
  end
  nil
end

def download_cli(base_url, version)
  temp_path = env_has_key("AC_TEMP_DIR")
  file_name = "sonar-scanner-cli-#{version}.zip"
  url = "#{base_url}/#{version}/#{file_name}"
  zip_path = File.join(temp_path, file_name)

  puts "Downloading SonarScanner CLI #{version} from #{url}"
  run_command("curl -fsSL --retry 3 -o #{Shellwords.escape(zip_path)} #{Shellwords.escape(url)}")

  expected = fetch("#{url}.sha256").split.first.to_s.downcase
  actual = Digest::SHA256.file(zip_path).hexdigest
  abort("SHA-256 mismatch for #{file_name}: expected '#{expected}', got '#{actual}'") unless expected == actual
  puts "SHA-256 verified: #{actual}"

  run_command("unzip -qq -o #{Shellwords.escape(zip_path)} -d #{Shellwords.escape(temp_path)}")
  File.delete(zip_path)
  File.join(temp_path, "sonar-scanner-#{version}", "bin", "sonar-scanner")
end

repository_path = env_has_key("AC_REPOSITORY_DIR")
sonar_parameters = ENV["AC_SONAR_PARAMETERS"]
extra_parameters = ENV["AC_SONAR_EXTRA_PARAMETERS"]
sonar_properties = (Pathname.new repository_path).join("sonar-project.properties")

if sonar_parameters.nil?
  puts "No project parameters found. Using project's sonar-project.properties"
else
  if File.exist?(sonar_properties)
    puts "sonar-project.properties exists appending to it"
    File.open(sonar_properties, "a") do |file|
      file.puts sonar_parameters
    end
  else
    puts "Creating sonar-project.properties"
    File.open(sonar_properties, "w") do |file|
      file.write(sonar_parameters)
    end
  end
end

base_url = scanner_base_url
cli_version = resolve_version(base_url)
scanner = installed_scanner(cli_version)
if scanner.nil?
  scanner = download_cli(base_url, cli_version)
else
  puts "Using the installed SonarScanner CLI #{cli_version}: #{scanner}"
end

command = Shellwords.escape(scanner)
if !extra_parameters.nil? && extra_parameters != ""
  command.concat(" #{extra_parameters}")
end

Dir.chdir(repository_path) {
  run_command(command)
}
