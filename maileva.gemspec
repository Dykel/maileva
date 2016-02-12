# Copyright © 2016, Kévin Lesénéchal <kevin.lesenechal@gmail.com>.
#
# This library is licensed under the new BSD license. Checkout the license text
# in the LICENSE file or online at <http://opensource.org/licenses/BSD-3-Clause>.

require 'rake'

Gem::Specification.new do |s|
  s.name     = "maileva"
  s.version  = "0.1.1"
  s.license  = "BSD-3-Clause"
  s.summary  = "Send mails through Maileva FTP deposit"
  s.author   = "Kévin Lesénéchal"
  s.email    = "kevin.lesenechal@gmail.com"
  s.homepage = "https://github.com/kevin-lesenechal/paybox_direct"
  s.files    = FileList["lib/**/*", "[A-Z]*", "spec/*"].to_a
  s.add_dependency "double-bag-ftps", "~> 0.1"
  s.add_development_dependency "rspec", "~> 3.0"
end
