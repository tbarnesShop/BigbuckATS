# frozen_string_literal: true

require "tmpdir"
require "zlib"
require_relative "../../app/services/document_scanner"

module LocalSecurity
  class ScannerCheck
    def self.run!
      original = ENV["BIGBUCK_CLAMAV_DATABASE"]
      Dir.mktmpdir("bigbuck-scanner") do |directory|
        # Official harmless EICAR test pattern; this tiny definition tests the
        # engine wiring only, never production signature coverage.
        eicar = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
        signatures = File.join(directory, "test.ndb")
        File.write(signatures, "BigBuck.Test.Eicar:0:*:#{eicar.unpack1('H*')}\n")
        ENV["BIGBUCK_CLAMAV_DATABASE"] = signatures
        { "clean" => "%PDF-1.4 harmless", "infected" => eicar }.each do |expected, content|
          path = File.join(directory, expected)
          File.write(path, content)
          raise Error, "Real ClamAV #{expected} check failed" unless DocumentScanner.call(path) == expected
        end
        large = File.join(directory, "oversize.gz")
        Zlib::GzipWriter.open(large) { |file| file.write("x" * (11 * 1024 * 1024)) }
        raise Error, "ClamAV scan limit did not fail closed" unless DocumentScanner.call(large) == "infected"
        ENV["BIGBUCK_CLAMAV_DATABASE"] = File.join(directory, "missing.ndb")
        raise Error, "Missing definitions did not fail closed" unless DocumentScanner.call(large) == "failed"
      end
      puts "Real ClamAV passed clean, EICAR, scan limit and unavailable-definition checks (test signatures only)."
    ensure
      ENV["BIGBUCK_CLAMAV_DATABASE"] = original
    end
  end
end
