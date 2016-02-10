# Copyright © 2016, Kévin Lesénéchal <kevin.lesenechal@gmail.com>.
#
# This library is licensed under the new BSD license. Checkout the license text
# in the LICENSE file or online at <http://opensource.org/licenses/BSD-3-Clause>.

require 'spec_helper'
require 'maileva'
require 'double_bag_ftps'
require 'fileutils'
require 'pathname'

RSpec.describe Maileva::Batch do
  before do
    Maileva.class_variable_set(:@@rules, {})
    Maileva.add_rule :grids, id: "bar", name: "baz"
  end

  it "adds files" do
    expect(File).to receive(:file?).at_least(:once).and_return(true)

    batch = Maileva::Batch.new(:grids, "my_batch")
    expect {
      batch.append_file "lorem.pdf"
      batch.append_file "ipsum.pdf", "dolor.pdf"
      batch << "sit.pdf"
      batch << %w(amet.pdf consectetur.pdf adipiscing.pdf)
    }.to change{ batch.files }.from([]).to(%w(lorem.pdf ipsum.pdf dolor.pdf sit.pdf amet.pdf consectetur.pdf adipiscing.pdf))
  end

  it "has a temp directory" do
    Maileva.config.files_root = Pathname.new("/my/maileva/files")
    batch = Maileva::Batch.new(:grids, "my_batch")
    expect(batch.tmp_dir).to eq Pathname.new("/my/maileva/files/grids/my_batch")
  end

  it "rejects non-existing files" do
    expect(File).to receive(:file?).with("non_existing.pdf").and_return(false)

    batch = Maileva::Batch.new(:grids, "my_batch")
    expect {
      batch << "non_existing.pdf"
    }.to raise_error("non_existing.pdf: no such file for batch 'my_batch' (grids)")
  end

  it "rejects non-PDF files" do
    expect(File).to receive(:file?).with("invalid_file.png").and_return(true)

    batch = Maileva::Batch.new(:grids, "my_batch")
    expect {
      batch << "invalid_file.png"
    }.to raise_error("invalid_file.png: expecting .pdf")
  end

  it "sends batches if under threshold" do
    expect(File).to receive(:file?).at_least(:once).and_return(true)

    Maileva.config.confirmation_threshold = 100
    batch = Maileva::Batch.new(:grids, "my_batch")
    batch << "hello.pdf" << "world.pdf"
    expect(batch).to receive(:send!)
    batch.send
  end

  it "asks confirmation if above threshold" do
    expect(File).to receive(:file?).at_least(:once).and_return(true)

    Maileva.config.confirmation_threshold = 2
    batch = Maileva::Batch.new(:grids, "my_batch")
    batch << 5.times.map{|i| "file#{i + 1}.pdf"}.each do |file|
      expect(FileUtils).to receive(:cp).with(file, batch.tmp_dir + file)
    end
    confirm_cb = proc{}
    Maileva.on_confirmation_needed &confirm_cb

    expect(batch.files.size).to eq 5
    expect(File).to receive(:directory?).with(batch.tmp_dir).and_return(false)
    expect(FileUtils).to receive(:mkdir_p).with(batch.tmp_dir)
    expect(confirm_cb).to receive(:call).with(batch)
    batch.send
  end

  it "sends files to Maileva" do
    command_files = {}
    confirmed_cmds = []
    uploaded_files = []

    Maileva.config.ftp_login    = "my_login"
    Maileva.config.ftp_password = "my_pass"
    Maileva.config.client_id    = "my_client_id"

    expect(File).to receive(:file?).at_least(34).times.and_return(true)
    expect(File).to receive(:size).at_least(34).times.and_return(14556)
    expect_any_instance_of(DoubleBagFTPS).to receive(:putstr).at_least(:once) do |ftp, str, remote|
      command_files[remote] = str
    end
    expect_any_instance_of(DoubleBagFTPS).to receive(:put).at_least(:once) do |ftp, local, remote|
      uploaded_files << remote
    end
    expect_any_instance_of(DoubleBagFTPS).to receive(:rename).at_least(:once) do |ftp, from, to|
      confirmed_cmds << from
    end
    expect_any_instance_of(DoubleBagFTPS).to receive(:file_exists?).twice.and_return(false)
    expect_any_instance_of(DoubleBagFTPS).to receive(:connect).with("ftps.maileva.com", 21)
    expect_any_instance_of(DoubleBagFTPS).to receive(:login).with("my_login", "my_pass")

    batch = Maileva::Batch.new(:grids, "my_batch")
    batch << ("a".."z").map{|s| s * 8 + ".pdf" }
    batch << %w(lorem ipsum dolor sit amet foo bar baz).map{|s| s + ".pdf"}

    processing_cb = proc{}
    done_cb = proc{}
    Maileva.on_batch_processing &processing_cb
    Maileva.on_batch_sent &done_cb
    expect(processing_cb).to receive(:call).with(batch)
    expect(done_cb).to receive(:call).with(batch)

    batch.send!

    expect(uploaded_files.size).to eq 34
    expect(command_files.keys).to eq(["grids_my_batch_1.tmp", "grids_my_batch_2.tmp"])
    i = 0
    command_files.values.each do |cmd|
      expect(cmd).to include "CLIENT_ID=my_client_id\n"
      expect(cmd).to include "NB_FILE=#{i == 0 ? 30 : 4}\n"
      expect(cmd).to include "GATEWAY=FLOW\n"
      expect(cmd).to include "FLOW_RULE=bar\n"
      j = 1
      (i == 0 ? uploaded_files[0, 30] : uploaded_files[30..-1]).each do |file|
        expect(cmd).to include "FILE_NAME_#{j}=#{file}\n"
        expect(cmd).to include "FILE_SIZE_#{j}=14556\n"
        j += 1
      end
      i += 1
    end
    expect(confirmed_cmds).to eq command_files.keys
  end

  it "rollbacks in case of an error" do
    Maileva.config.ftp_login    = "my_login"
    Maileva.config.ftp_password = "my_pass"
    Maileva.config.client_id    = "my_client_id"

    expect(File).to receive(:file?).at_least(34).times.and_return(true)
    expect(File).to receive(:size).at_least(34).times.and_return(14556)

    batch = Maileva::Batch.new(:grids, "my_batch")
    batch << ("a".."z").map{|s| s * 8 + ".pdf" }
    batch << %w(lorem ipsum dolor sit amet foo bar baz).map{|s| s + ".pdf"}

    expect(batch).to receive(:rollback!).and_call_original
    expect_any_instance_of(DoubleBagFTPS).to receive(:rename) { raise "Dummy exception" }
    expect_any_instance_of(DoubleBagFTPS).to receive(:putstr).at_least(:once)
    expect_any_instance_of(DoubleBagFTPS).to receive(:put).at_least(:once)
    expect_any_instance_of(DoubleBagFTPS).to receive(:file_exists?).twice.and_return(false)
    expect_any_instance_of(DoubleBagFTPS).to receive(:connect).with("ftps.maileva.com", 21)
    expect_any_instance_of(DoubleBagFTPS).to receive(:login).with("my_login", "my_pass")
    ["grids_my_batch_1", "grids_my_batch_2"].each do |f|
      expect_any_instance_of(DoubleBagFTPS).to receive(:delete).with(f + ".tmp")
      expect_any_instance_of(DoubleBagFTPS).to receive(:delete).with(f + ".flw")
      files = f == "grids_my_batch_1" ? batch.files[0, 30] : batch.files[30..-1]
      files.each_index do |i|
        expect_any_instance_of(DoubleBagFTPS).to receive(:delete).with(sprintf "%s.%03d", f, i + 1)
      end
    end

    processing_cb = proc{}
    failure_cb = proc{}
    Maileva.on_batch_processing &processing_cb
    Maileva.on_batch_failure &failure_cb
    expect(processing_cb).to receive(:call).with(batch)
    expect(failure_cb).to receive(:call).with(batch)

    expect{ batch.send! }.to raise_error("Dummy exception")
  end
end
