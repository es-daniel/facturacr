require 'thor'
require 'awesome_print'
require 'facturacr'
require 'facturacr/cli/generate'
require 'fileutils'
=begin
require 'facturacr/document'
require 'facturacr/document/fax'
require 'facturacr/document/identification_document'
require 'facturacr/document/issuer'
require 'facturacr/document/receiver'
require 'facturacr/document/location'
require 'facturacr/document/phone_type'
require 'facturacr/document/phone'
require 'facturacr/document/item'
require 'facturacr/document/tax'
require 'facturacr/document/summary'
require 'facturacr/document/regulation'
require 'facturacr/document/reference'

require 'facturacr/invoice'
require 'facturacr/credit_note'
require 'facturacr/signer/signer'
require 'facturacr/api'
require 'facturacr/signed_document'
require 'facturacr/builder'
require 'facturacr/xml_document'
=end
module FE
  
  module Utils
    def self.configure(path)
      FE.configure do |config|
        config.mode = "file"
        config.file_path = path
        config.environment = "test"
      end
    end
  end
  
  class CLI < Thor
    
    desc "check KEY", "checks a sent document in the api"
    method_option :config_file, aliases: '-c', desc: "default configuration file", default: "tmp/config.yml"
    
    def check(key)
      FE::Utils.configure(options[:config_file])
      api = FE::Api.new
      document_status = api.get_document_status(key)
      ap document_status.to_h
    end
    
    desc "generate DOCUMENT ARGS", "generate xml documents"
    subcommand "generate", Generate
   
    desc "sign XML_IN XML_OUT", "signs the xml document and stores the signed document in the output path"
    method_option :config_file, aliases: '-c', desc: "default configuration file", default: "tmp/config.yml"
    def sign(xml_in, xml_out)
      FE::Utils.configure(options[:config_file])
      signer = FE::JavaSigner.new FE.configuration.key_path, FE.configuration.key_password, xml_in, xml_out
      #signer = FE::NokoSigner.new FE.configuration.key_path, FE.configuration.key_password, xml_in, xml_out
      signer.sign
    end
    
    desc "send_document SIGNED_XML", "sends the SIGNED_XML file to the API"
    method_option :config_file, aliases: '-c', desc: "default configuration file", default: "tmp/config.yml"
    def send_document(path)
      FE::Utils.configure(options[:config_file])
      xml_document = FE::XmlDocument.new(path)
      document = xml_document.document
      signed_document = FE::SignedDocument.new(document,path)
      api = FE::Api.new
      payload = signed_document.payload
      if api.send_document(payload)
        puts "Document Sent".green
        puts "KEY: #{document.key}"
        puts "Wait 5 seconds before check..."
        sleep 5
        if document.is_a?(FE::ReceptionMessage)
          check_key = api.check_location.split("/").last
        else
          check_key = document.key
        end
        invoke :check, [check_key], :config_file=>options[:config_file]
      else
        puts "ERROR".red
        ap api.errors
        raise "Sending Document Error" 
      end  
    end
    
        
    desc "setup PATH", "will create a tmp directory with a sample config file and a sample data file at the specified path."
    def setup(path)
      puts "\n\n SETUP FACTURACR \n\n"
      say "A tmp directory will be created at: #{path}"
      say "config.yml file will be copied to #{path}"
      say "data.yml file will be copied to #{path}"
      answer = ask("Are you sure you want to continue?", :yellow, limited_to: ["y","n"])
      if answer.downcase == "y"
        FileUtils.mkdir_p "#{path}/tmp"
        FileUtils.cp "#{FE.root}/resources/data.yml", "#{path}/tmp/data.yml"
        FileUtils.cp "#{FE.root}/config/config.yml", "#{path}/tmp/config.yml"
        say "Done.", :green
      else
        say "Ok. Bye", :green
      end
    end
    
    
  end
end