require 'modaldiagrams/version'
require 'modaldiagrams/parameters'
require 'modaldiagrams/modaldiagrams'

if defined?(Rails) && Rails.respond_to?(:version)
  if Rails.version.split('.').first.to_i > 2
    class BackupTask < Rails::Railtie
      rake_tasks do
        Dir[File.join(File.dirname(__FILE__), 'tasks', '**/*.rake')].each { |f| load f }
      end
    end
  end
  ModalDiagrams.enable_clusters if defined?(ActiveRecord::Base)
end
