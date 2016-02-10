# Copyright © 2016, Kévin Lesénéchal <kevin.lesenechal@gmail.com>.
#
# This library is licensed under the new BSD license. Checkout the license text
# in the LICENSE file or online at <http://opensource.org/licenses/BSD-3-Clause>.

require 'double_bag_ftps'

class Maileva::Batch
  attr_accessor :type, :name
  attr_reader   :files, :rule

  PART_SIZE = 30

  def initialize(type, name)
    raise ArgumentError, "Invalid Maileva batch type '#{type}'" unless type.is_a?(Symbol) and Maileva.rules.key?(type)

    @type  = type
    @name  = name
    @rule  = Maileva.rules[@type]
    @files = []
  end

  def append_file(*files)
    files.each do |file|
      if file.is_a? Array
        file.each{|f| append_file(f)}
        return
      end

      raise ArgumentError, "Expecting string for 'file'" unless file.is_a?(String)
      raise "#{file}: no such file for batch '#{@name}' (#{@type})" unless File.file?(file)
      raise "#{file}: expecting .pdf" unless File.extname(file) == ".pdf"

      @files << file
    end
  end
  alias << append_file

  def tmp_dir
    return Maileva.config.files_root + @type.to_s + @name
  end

  def uploaded_count
    return @uploaded_remote_names.size
  end

  def send
    if @files.size < Maileva.config.confirmation_threshold
      send!
    else
      FileUtils.mkdir_p tmp_dir unless File.directory?(tmp_dir)
      @files.each do |file|
        FileUtils.cp file, tmp_dir + File.basename(file) unless file.start_with? tmp_dir.to_s
      end

      Maileva.class_variable_get(:@@confirmation_callbacks).each{|proc| proc.call(self)}
    end
  end

  def send!(in_db: false)
    raise "Cannot send empty batch" if @files.size == 0

    Maileva.class_variable_get(:@@processing_callbacks).each{|proc| proc.call(self, in_db)}

    @uploaded_remote_names = []
    @uploaded_part_names   = []

    Maileva::BATCHES_IN_PROCESS_MUTEX.synchronize{ Maileva.batches_in_process << self }

    ftp = nil
    begin
      ftp = DoubleBagFTPS.new
      ftp.passive = true
      ftp.connect("ftps.maileva.com", 21)
      ftp.login(Maileva.config.ftp_login, Maileva.config.ftp_password)

      begin
        part_no = 1
        @files.each_slice(PART_SIZE) do |part|
          send_part(ftp, part, part_no)
          part_no += 1
        end

        @uploaded_part_names.each do |part|
          ftp.rename part + ".tmp", part + ".flw"
        end
      rescue Exception => e
        rollback!(ftp)
        raise e
      end

      Maileva.class_variable_get(:@@done_callbacks).each{|proc| proc.call(self)}
    rescue Exception => e
      Maileva.class_variable_get(:@@failure_callbacks).each{|proc| proc.call(self)}
      raise e
    ensure
      Maileva::BATCHES_IN_PROCESS_MUTEX.synchronize{ Maileva.batches_in_process.delete(self) }
      begin; ftp.close unless ftp.nil? or ftp.closed? rescue Exception; end
    end
  end

private

  def send_part(ftp, part, part_no)
    part_name = sprintf "%s_%s_%d", @type, @name, part_no
    cmd_file_name = part_name + ".tmp"
    cmd_file = "CLIENT_ID=#{Maileva.config.client_id}\n" +
               "NB_FILE=#{part.size}\n" +
               "GATEWAY=FLOW\n" +
               "FLOW_RULE=#{@rule[:id]}\n"
    raise "Command file '#{cmd_file_name}' already exists on server" if ftp.file_exists?(cmd_file_name)
    ftp.putstr "", cmd_file_name
    @uploaded_part_names << part_name

    file_no = 1
    part.each do |file|
      file_name = sprintf "%s.%03d", part_name, file_no
      cmd_file += "FILE_NAME_#{file_no}=#{file_name}\n" +
                  "FILE_SIZE_#{file_no}=#{File.size(file)}\n"
      ftp.put file, file_name
      Maileva::BATCHES_IN_PROCESS_MUTEX.synchronize{ @uploaded_remote_names << file_name }
      file_no += 1
    end
    ftp.putstr cmd_file, cmd_file_name
  end

  def rollback!(ftp)
    @uploaded_part_names.each do |part|
      begin; ftp.delete part + ".flw" rescue Exception; end
    end
    @uploaded_part_names.each do |part|
      begin; ftp.delete part + ".tmp" rescue Exception; end
    end
    @uploaded_remote_names.each do |file|
      begin; ftp.delete file rescue Exception; end
    end
  end
end
