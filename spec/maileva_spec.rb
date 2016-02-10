# Copyright © 2016, Kévin Lesénéchal <kevin.lesenechal@gmail.com>.
#
# This library is licensed under the new BSD license. Checkout the license text
# in the LICENSE file or online at <http://opensource.org/licenses/BSD-3-Clause>.

require 'spec_helper'
require 'maileva'
require 'double_bag_ftps'

RSpec.describe Maileva do
  it "should add rules" do
    Maileva.class_variable_set(:@@rules, {})
    expect {
      Maileva.add_rule :grids, id: "bar", name: "baz"
    }.to change{ Maileva.rules }.from({}).to({grids: {id: "bar", name: "baz"}})
  end
end
