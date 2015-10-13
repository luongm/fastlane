module FastlaneCore
  # This class checks if a specific certificate is installed on the current mac
  class CertChecker
    def self.installed?(path)
      raise "Could not find file '#{path}'".red unless File.exist?(path)

      ids = installed_identies
      finger_print = sha1_fingerprint(path)

      return ids.include? finger_print
    end

    def self.wwdr_certificate_installed?
      certificate_name = "Apple Worldwide Developer Relations Certification Authority"
      `security find-certificate -c #{certificate_name}`
      $?.success?
    end

    def self.install_wwdr_certificate
      Dir.chdir '/tmp'
      url = 'https://developer.apple.com/certificationauthority/AppleWWDRCA.cer'
      filename = File.basename(url)
      `curl -O #{url} && security import #{filename} -k login.keychain`
      raise "Could not install WWDR certificate".red unless $?.success?
    end

    # Legacy Method, use `installed?` instead
    # rubocop:disable Style/PredicateName
    def self.is_installed?(path)
      installed?(path)
    end
    # rubocop:enable Style/PredicateName

    def self.installed_identies
      install_wwdr_certificate unless wwdr_certificate_installed?

      available = `security find-identity -v -p codesigning`
      ids = []
      available.split("\n").each do |current|
        next if current.include? "REVOKED"
        begin
          (ids << current.match(/.*\) (.*) \".*/)[1])
        rescue
          # the last line does not match
        end
      end

      return ids
    end

    def self.sha1_fingerprint(path)
      result = `openssl x509 -in "#{path}" -inform der -noout -sha1 -fingerprint`
      begin
        result = result.match(/SHA1 Fingerprint=(.*)/)[1]
        result.delete!(':')
        return result
      rescue
        Helper.log.info result
        raise "Error parsing certificate '#{path}'"
      end
    end
  end
end
