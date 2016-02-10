module CoreExtensions
  module Net
    module FTP
      module Maileva
        def file_exists?(path)
          begin
            size(path)
            return true
          rescue Net::FTPError => e
            err_code = e.message[0, 3].to_i
            raise "SIZE unimplemented on server" if err_code == 500 or err_code == 502
            return false
          end
        end

        def putstr(str, remote, &block)
          f = StringIO.new(str)
          begin
            storlines("STOR #{remote}", f, &block)
          ensure
            f.close
          end
        end
      end
    end
  end
end
