require "pathname"
require 'json'
require 'dotenv'

Dotenv.load

def env_has_key(key)
    !ENV[key].nil? && ENV[key] != '' ? ENV[key] : abort("Missing #{key}.")
  end

def run_command(command)
    puts "@@[command] #{command}"
    unless system(command)
      exit $?.exitstatus
    end
end

def download_cli(version)
    puts "Downloading SonarQube CLI version #{version}..."
    temp_path = env_has_key("AC_TEMP_DIR")
    download_path = "#{temp_path}/sonar-scanner-cli-#{version}.zip"
    extract_path = "#{temp_path}/sonar-scanner-#{version}"
    run_command("curl -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-#{version}.zip -o #{download_path}")
    run_command("unzip -qq -u -o #{download_path} -d #{temp_path}")
    run_command("rm  #{download_path}")
    return extract_path
end
  
repository_path = env_has_key('AC_REPOSITORY_DIR')
sonar_parameters = ENV['AC_SONAR_PARAMETERS']
extra_parameters = ENV['AC_SONAR_EXTRA_PARAMETERS']
sonar_properties = (Pathname.new repository_path).join('sonar-project.properties')

if sonar_parameters.nil?
    puts "No project parameters found. Using project's sonar-project.properties"
else
    if File.exist?(sonar_properties)
        puts "sonar-project.properties exists appending to it"
        File.open(sonar_properties, 'a') do |file|
            file.puts sonar_parameters
        end
    else
        puts "Creating sonar-project.properties"
        File.open(sonar_properties, 'w') do |file|
            file.write(sonar_parameters)
        end
     end
end

cli_version =  ENV['AC_SONAR_VERSION'] || 'latest'
if cli_version == 'latest'
    puts "Getting latest SonarQube CLI version number..."
    json = JSON.parse(`curl -s https://api.github.com/repos/SonarSource/sonar-scanner-cli/releases/latest`)
    cli_version = json['tag_name']
end

cli_path = download_cli(cli_version)
command = "#{cli_path}/bin/sonar-scanner"
if  !extra_parameters.nil? && extra_parameters != ''
    command.concat(" #{extra_parameters}")
end

Dir.chdir(repository_path){
  run_command(command)
}
