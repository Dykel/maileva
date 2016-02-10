# Copyright © 2016, Kévin Lesénéchal <kevin.lesenechal@gmail.com>.
#
# This library is licensed under the new BSD license. Checkout the license text
# in the LICENSE file or online at <http://opensource.org/licenses/BSD-3-Clause>.

require 'core_extensions/net/ftp/maileva'
require 'double_bag_ftps'
require 'ostruct'

Net::FTP.include CoreExtensions::Net::FTP::Maileva

module Maileva
  @@config = OpenStruct.new({
    files_root:   nil,
    ftp_login:    nil,
    ftp_password: nil,
    client_id:    nil,
    confirmation_threshold: 100
  })

  @@confirmation_callbacks = []
  @@processing_callbacks = []
  @@done_callbacks = []
  @@failure_callbacks = []

  @@rules = {}
  @@batches_in_process = []

  BATCHES_IN_PROCESS_MUTEX = Mutex.new

  def self.config
    @@config
  end

  def self.rules
    @@rules
  end

  def self.batches_in_process
    @@batches_in_process
  end

  def self.add_rule(name, opts)
    raise ArgumentError, "name: expecting string" if !name.is_a?(Symbol)
    raise ArgumentError, "Expecting option 'id'" if !opts.key?(:id)

    @@rules[name] = opts
  end

  def self.on_confirmation_needed(&block)
    @@confirmation_callbacks << block
  end

  def self.on_batch_processing(&block)
    @@processing_callbacks << block
  end

  def self.on_batch_sent(&block)
    @@done_callbacks << block
  end

  def self.on_batch_failure(&block)
    @@failure_callbacks << block
  end
end

require 'maileva/batch'
